#!/bin/bash
# Sync local changes to the Pi and restart services.
# Usage: ./sync-to-pi.sh [pi@host]  (defaults to pi@frame.local)

PI_HOST="${1:-pi@frame.local}"

rsync -avz \
    --exclude='content/*' \
    --exclude='state.json' \
    --exclude='__pycache__' \
    --exclude='.git' \
    ./ $PI_HOST:~/arena-frame/

scp system/config/hostapd.conf $PI_HOST:/tmp/hostapd.conf
scp system/config/wifi-portal.conf $PI_HOST:/tmp/wifi-portal.conf
ssh $PI_HOST "sudo cp /tmp/hostapd.conf /etc/hostapd/hostapd.conf && sudo cp /tmp/wifi-portal.conf /etc/dnsmasq.d/wifi-portal.conf"

ssh $PI_HOST "sudo systemctl restart arena-frame arena-buttons"

echo "Synced and restarted services"
