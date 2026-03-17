# Arena Frame

Bring an Are.na channel into your space

Arena Frame is an open-source object that connects to [Are.na](https://are.na) and displays a channel's content on a colour e-ink screen. Choose between cycling through blocks or displaying new ones live as they come in.

Revisit your visual references in a slower way, let your research surface throughout the day.
Connect a shared channel with freinds and send each other virtual postcards. We're curious to see what you do with it!

---

## What You'll Need

- Raspberry Pi Zero 2 W (ideally with presoldered header pins)
- [Pimoroni Inky Impression](https://shop.pimoroni.com/products/inky-impression) (available in 4", 7.3" and 13.3" flavours)
- MicroSD card (8GB or larger)
- 5v DC Micro USB power source

---

## Setup

### Step 1: Download the Image

1. Go to [Releases](https://github.com/k-sdm/arena-frame/releases)
2. Download `arenaframe.img.zip` (you don't need to unzip it)

### Step 2: Install Raspberry Pi Imager

1. Go to [raspberrypi.com/software](https://www.raspberrypi.com/software/)
2. Download Raspberry Pi Imager for your computer (Mac, Windows, or Linux)
3. Install and open it

### Step 3: Flash the Image

1. Insert your MicroSD card into your computer
2. In Raspberry Pi Imager, click **Choose Device** → select **Raspberry Pi Zero 2 W**
3. Click **Choose OS** → scroll to the bottom → click **Use custom**
4. Select the `arenaframe.img.zip` file you downloaded
5. Click **Choose Storage** → select your MicroSD card
6. Click **Next** and start writing
7. Wait for it to complete, then remove the SD card

### Step 4: Assemble and Power On

1. Insert the MicroSD card into your Raspberry Pi
2. Connect the Inky Impression display to the GPIO pins
3. Connect power via either micro USB port
4. Wait about 60 seconds — the white LED will start blinking

### Step 5: Connect and Configure

1. On your phone or laptop, open WiFi settings
2. Connect to the network **ArenaFrame-Setup** (password: `arenaframe`)
3. A configuration page should open automatically
   - If it doesn't, open a browser and go to `http://192.168.4.1`
4. Select your WiFi network from the dropdown, or select 'Other' and enter it's name if it doesnt show up
5. Enter your WiFi password
6. Enter your Are.na channel slug — this is the last part of your channel URL
   - Example: if your channel is `are.na/username/my-inspiration`, enter `my-inspiration`
7. Choose the refresh behaviour
8. Tap **Save**
9. Optionally enter your [personal access token](https://www.are.na/settings/personal-access-tokens) if you're connecting a private channel 

---

## Configuration Options

| Setting | Description |
|---------|-------------|
| **Refresh** | How often to check for new content (Live, 5 min, 15 min, 30 min, 1 hr, 12 hr, 24 hr) |
| **Order** | Display order when cycling through blocks (Random, Newest first, Oldest first) |
| **Show Channel Name** | Display an overlay with the block name and channel info |
| **Dark Mode** | Dark background for text blocks |
| **Access Token** | Required for private channels — get yours at [dev.are.na](https://dev.are.na/oauth/applications) |

---

## Re-entering Setup Mode

If you need to change WiFi or channel settings:

- **Hold Button A for 3 seconds** (the top button on the display)
- The LED will start blinking and the ArenaFrame-Setup network will reappear

The frame also enters setup mode automatically if it can't connect to WiFi or if the channel slug is incorrect.

---

## Hacking / Modding

Arena Frame is designed to be modified. SSH is enabled by default.

### Connect via SSH

Make sure your computer is on the same WiFi network as the frame.

```bash
ssh pi@frame.local
```

Password: `arenaframe`

If `frame.local` doesn't resolve, find the IP address from your router and use that instead.

### Project Structure

```
~/arena-frame/
├── main.py              # Entry point
├── config.py            # Configuration management
├── sources/             # Content sources (Are.na API)
├── display/             # E-ink rendering
├── portal/              # WiFi setup web portal
├── hardware/            # Buttons and LED
└── wifi/                # WiFi management
```

### Useful Commands

```bash
# View live logs
sudo journalctl -u arena-frame -f

# Restart the display service
sudo systemctl restart arena-frame

# Stop all services
sudo systemctl stop arena-frame arena-buttons wifi-manager

# Update to latest version
cd ~/arena-frame && git pull
sudo systemctl restart arena-frame
```

### Configuration File

Settings are stored at `/etc/photoframe/config.json`:

```json
{
  "channel_slug": "your-channel",
  "refresh": "live",
  "order": "newest",
  "show_info": true,
  "dark_mode": false
}
```

---

## Alternative: Install Script

If you already have a Raspberry Pi running Raspberry Pi OS, you can install Arena Frame using the install script.

### Requirements

- Raspberry Pi with Raspberry Pi OS (Bookworm or later)
- Pimoroni Inky Impression connected

### Installation

```bash
git clone https://github.com/ks-dm/arena-frame.git
cd arena-frame
./install.sh
```

The script will install all dependencies, configure services, and set up the WiFi portal.

When complete:

```bash
sudo reboot
```

Then connect to **ArenaFrame-Setup** to configure.

---

## Troubleshooting

**LED keeps blinking, display doesn't update**
- WiFi credentials may be incorrect
- Channel slug may be wrong
- Reconnect to ArenaFrame-Setup and check your settings

**Can't find ArenaFrame-Setup network**
- Make sure you're close to the frame
- Try power cycling the Pi
- Hold Button A for 3 seconds to force setup mode

**Private channel not working**
- You need an access token for private channels
- Get one at [dev.are.na](https://dev.are.na/oauth/applications)
- Enter it in the Advanced section of the setup portal

**Display shows old content**
- Check logs: `sudo journalctl -u arena-frame -f`
- Restart: `sudo systemctl restart arena-frame`

---

## License

MIT — do whatever you want with it.

---

## Credits

- Built for [Are.na](https://are.na)
- Display library by [Pimoroni](https://github.com/pimoroni/inky)
