#!/bin/bash
# Arena Frame installer for Raspberry Pi
# Usage: git clone https://github.com/k-sdm/arena-frame.git && cd arena-frame && sudo ./install.sh
set -euo pipefail

INSTALL_DIR="/home/pi/arena-frame"
VENV_DIR="/home/pi/.virtualenvs/pimoroni"
CONFIG_DIR="/etc/photoframe"
USER="pi"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}::${NC} $1"; }
warn()  { echo -e "${YELLOW}:: WARNING:${NC} $1"; }
error() { echo -e "${RED}:: ERROR:${NC} $1"; exit 1; }

# ------------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------------

[[ $EUID -ne 0 ]] && error "This script must be run as root (use: sudo ./install.sh)"

if ! id "$USER" &>/dev/null; then
    error "User '$USER' does not exist. This installer expects a standard Raspberry Pi OS setup."
fi

if ! grep -qi "raspberry\|bcm" /proc/cpuinfo 2>/dev/null; then
    warn "This doesn't look like a Raspberry Pi — things may not work."
fi

echo ""
echo -e "${BOLD}Arena Frame Installer${NC}"
echo "=============================="
echo ""

# ------------------------------------------------------------------
# 1. System packages
# ------------------------------------------------------------------

info "Updating package lists..."
apt-get update -qq

info "Installing system dependencies..."
apt-get install -y -qq \
    python3 python3-pip python3-venv python3-dev \
    git \
    hostapd dnsmasq \
    wireless-tools wpasupplicant \
    iw iptables \
    libgpiod-dev \
    libjpeg-dev libopenjp2-7 libtiff-dev \
    fonts-dejavu-core \
    > /dev/null

# ------------------------------------------------------------------
# 2. Enable SPI (required for Inky display)
# ------------------------------------------------------------------

info "Enabling SPI interface..."
raspi-config nonint do_spi 0 2>/dev/null || {
    BOOT_CONFIG="/boot/firmware/config.txt"
    [[ ! -f "$BOOT_CONFIG" ]] && BOOT_CONFIG="/boot/config.txt"
    if [[ -f "$BOOT_CONFIG" ]] && ! grep -q "^dtparam=spi=on" "$BOOT_CONFIG"; then
        echo "dtparam=spi=on" >> "$BOOT_CONFIG"
        info "Added dtparam=spi=on to $BOOT_CONFIG"
    fi
}

# ------------------------------------------------------------------
# 3. Stop existing services
# ------------------------------------------------------------------

info "Stopping existing services (if any)..."
for svc in arena-frame arena-buttons arena-led wifi-manager wifi-portal-web; do
    systemctl stop "$svc" 2>/dev/null || true
done

# ------------------------------------------------------------------
# 4. Project directory
# ------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    info "Copying project to $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
    rsync -a --exclude='.git' --exclude='__pycache__' --exclude='content/' \
        --exclude='state.json' --exclude='.DS_Store' \
        "$SCRIPT_DIR/" "$INSTALL_DIR/"
else
    info "Already running from $INSTALL_DIR"
fi

mkdir -p "$INSTALL_DIR/content"
chown -R "$USER:$USER" "$INSTALL_DIR"

# ------------------------------------------------------------------
# 5. Python virtual environment
# ------------------------------------------------------------------

info "Setting up Python virtual environment at $VENV_DIR..."
mkdir -p "$(dirname "$VENV_DIR")"
chown "$USER:$USER" "$(dirname "$VENV_DIR")"

if [[ ! -d "$VENV_DIR" ]]; then
    sudo -u "$USER" python3 -m venv "$VENV_DIR" --system-site-packages
fi

PYTHON="$VENV_DIR/bin/python"
PIP="$VENV_DIR/bin/pip"

sudo -u "$USER" "$PIP" install --upgrade pip setuptools wheel -q

info "Installing Python packages..."
sudo -u "$USER" "$PIP" install -q \
    requests \
    Pillow \
    flask \
    gpiozero \
    gpiod \
    gpiodevice \
    "inky[rpi]"

# ------------------------------------------------------------------
# 6. Configuration files
# ------------------------------------------------------------------

info "Setting up configuration..."
mkdir -p "$CONFIG_DIR"

if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
    cat > "$CONFIG_DIR/config.json" << 'JSON'
{
  "channel_slug": "",
  "arena_token": null,
  "refresh": "live",
  "order": "newest",
  "show_info": true,
  "dark_mode": false
}
JSON
    info "Created default config at $CONFIG_DIR/config.json"
fi
chmod 666 "$CONFIG_DIR/config.json"

# ------------------------------------------------------------------
# 7. hostapd
# ------------------------------------------------------------------

info "Configuring hostapd..."
cp "$INSTALL_DIR/system/config/hostapd.conf" /etc/hostapd/hostapd.conf

HOSTAPD_DEFAULT="/etc/default/hostapd"
if [[ -f "$HOSTAPD_DEFAULT" ]]; then
    sed -i 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' "$HOSTAPD_DEFAULT"
else
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > "$HOSTAPD_DEFAULT"
fi

systemctl unmask hostapd 2>/dev/null || true
systemctl disable hostapd 2>/dev/null || true

# ------------------------------------------------------------------
# 8. dnsmasq
# ------------------------------------------------------------------

info "Configuring dnsmasq..."
cp "$INSTALL_DIR/system/config/wifi-portal.conf" /etc/dnsmasq.d/wifi-portal.conf
systemctl disable dnsmasq 2>/dev/null || true

# ------------------------------------------------------------------
# 9. WPA supplicant baseline
# ------------------------------------------------------------------

WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
if [[ ! -f "$WPA_CONF" ]]; then
    info "Creating baseline WPA supplicant config..."
    cat > "$WPA_CONF" << 'WPA'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=GB
WPA
    chmod 600 "$WPA_CONF"
fi

# ------------------------------------------------------------------
# 10. systemd service files
# ------------------------------------------------------------------

info "Installing systemd services..."

cat > /etc/systemd/system/arena-frame.service << EOF
[Unit]
Description=Arena Frame Display
After=network-online.target wifi-manager.service
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON main.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/arena-buttons.service << EOF
[Unit]
Description=Arena Frame Button Handler
After=multi-user.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON -m hardware.buttons
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/arena-led.service << EOF
[Unit]
Description=Arena Frame LED Blinker

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON -m hardware.led
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/wifi-manager.service << EOF
[Unit]
Description=Arena Frame WiFi Manager
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON -m wifi.manager
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/wifi-portal-web.service << EOF
[Unit]
Description=Arena Frame WiFi Setup Portal

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON -m portal.app
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/arena-reconnect.service << EOF
[Unit]
Description=Arena Frame Reconnect (restarts display after config change)

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 10
ExecStart=/bin/systemctl restart arena-frame
EOF

# ------------------------------------------------------------------
# 11. Enable boot services
# ------------------------------------------------------------------

info "Enabling services..."
systemctl daemon-reload

systemctl enable arena-frame
systemctl enable arena-buttons
systemctl enable wifi-manager

# These are started/stopped dynamically by wifi-manager, not at boot
systemctl disable wifi-portal-web 2>/dev/null || true
systemctl disable arena-led 2>/dev/null || true
systemctl disable hostapd 2>/dev/null || true
systemctl disable dnsmasq 2>/dev/null || true

# ------------------------------------------------------------------
# 12. Hostname
# ------------------------------------------------------------------

info "Setting hostname to 'frame'..."
CURRENT_HOSTNAME=$(hostname)
if [[ "$CURRENT_HOSTNAME" != "frame" ]]; then
    hostnamectl set-hostname frame 2>/dev/null || echo "frame" > /etc/hostname
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\tframe/" /etc/hosts 2>/dev/null || true
fi

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------

echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo "  Reboot to start:"
echo "    sudo reboot"
echo ""
echo "  After reboot:"
echo "    1. Connect to 'ArenaFrame-Setup' WiFi (password: arenaframe)"
echo "    2. A setup page will open automatically"
echo "    3. Select your WiFi, enter your Are.na channel slug, and save"
echo ""
echo "  SSH:   ssh pi@frame.local  (password: arenaframe)"
echo "  Logs:  sudo journalctl -u arena-frame -f"
echo ""
