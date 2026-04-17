# Raspberry Pi 4 Direct WiFi Hotspot for iPhone

## What This Does

Configures the Raspberry Pi 4 (OpenFlexure microscope) to broadcast its own WiFi hotspot,
allowing an iPhone to connect directly to it — no router or internet needed.

## Connection Details

| Setting       | Value           |
|---------------|-----------------|
| Hotspot SSID  | `microscope`    |
| Password      | `openflexure`   |
| Pi IP         | `192.168.4.1`   |
| iPhone IP     | `192.168.4.x`   |

## Device Info

- **Hostname:** `microscope.local`
- **OS:** Raspbian GNU/Linux 10 (Buster)
- **SSH user:** `pi`
- **SSH password:** `openflexure`
- **Ethernet IP (Mac direct connection):** `169.254.103.118`

---

## What Was Done (Step by Step)

### 1. Connected Pi to home WiFi (temporary — to install packages)

Added WiFi credentials to wpa_supplicant:
```bash
sudo wpa_passphrase 'TSD29871ABCD' 'clavinova2025!' | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf
```

Unblocked WiFi radio (was RF-killed):
```bash
sudo sh -c 'echo 0 > /sys/class/rfkill/rfkill0/soft'
sudo sh -c 'echo 0 > /sys/class/rfkill/rfkill1/soft'
```

Connected and got IP via DHCP:
```bash
sudo ip link set wlan0 up
sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf
sudo dhclient wlan0
```

### 2. Fixed Raspbian Buster EOL repos

Raspbian Buster is end-of-life. Switched to Debian archive:
```
/etc/apt/sources.list:
deb http://archive.debian.org/debian buster main contrib non-free
deb http://archive.debian.org/debian-security buster/updates main
```

### 3. Installed hostapd and dnsmasq

```bash
sudo apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true
sudo apt-get install -y --allow-unauthenticated hostapd dnsmasq
```

### 4. Configured hostapd (WiFi Access Point)

File: `/etc/hostapd/hostapd.conf`
```
interface=wlan0
driver=nl80211
ssid=microscope
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=openflexure
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
```

Pointed hostapd to config in `/etc/default/hostapd`:
```
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```

### 5. Configured dnsmasq (DHCP server)

File: `/etc/dnsmasq.conf`
```
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
```

### 6. Set static IP for wlan0

Appended to `/etc/dhcpcd.conf`:
```
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
```

The `nohook wpa_supplicant` line prevents wpa_supplicant from managing wlan0
(which would conflict with hostapd acting as an AP).

### 7. Enabled and started services

```bash
sudo systemctl unmask hostapd
sudo systemctl enable hostapd dnsmasq
sudo systemctl restart dhcpcd
sudo systemctl start hostapd dnsmasq
```

---

## To Replicate on a Fresh Pi

Run all of the following on the Pi (via SSH or terminal):

```bash
# 1. Fix repos (Buster EOL)
sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://archive.debian.org/debian buster main contrib non-free
deb http://archive.debian.org/debian-security buster/updates main
EOF

# 2. Install packages
sudo apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true
sudo apt-get install -y --allow-unauthenticated hostapd dnsmasq

# 3. Configure hostapd
sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
interface=wlan0
driver=nl80211
ssid=microscope
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=openflexure
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# 4. Configure dnsmasq
sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF

# 5. Set static IP for wlan0
sudo sed -i '/^interface wlan0/,/^$/d' /etc/dhcpcd.conf
printf '\ninterface wlan0\n    static ip_address=192.168.4.1/24\n    nohook wpa_supplicant\n' | sudo tee -a /etc/dhcpcd.conf

# 6. Enable and start services
sudo systemctl unmask hostapd
sudo systemctl enable hostapd dnsmasq
sudo killall wpa_supplicant 2>/dev/null; sleep 1
sudo ip addr flush dev wlan0
sudo systemctl restart dhcpcd
sudo systemctl restart hostapd dnsmasq
```

---

## Issues Encountered and How They Were Solved

### Issue 1: WiFi radio was RF-killed (blocked)
When trying to bring up `wlan0`, it returned:
```
RTNETLINK answers: Operation not possible due to RF-kill
```
The WiFi chip was software-blocked. `rfkill` wasn't installed so we unblocked it directly via sysfs:
```bash
sudo sh -c 'echo 0 > /sys/class/rfkill/rfkill0/soft'
sudo sh -c 'echo 0 > /sys/class/rfkill/rfkill1/soft'
```

### Issue 2: wpa_supplicant already running — couldn't start a second instance
When trying to connect to home WiFi, wpa_supplicant failed with:
```
ctrl_iface exists and seems to be in use - cannot override it
```
A previous instance had left a stale socket. Fixed by killing the old process and removing the socket:
```bash
sudo killall wpa_supplicant
sudo rm -f /var/run/wpa_supplicant/wlan0
```

### Issue 3: Raspbian Buster repos are EOL — apt-get failed
`apt-get update` failed because `raspbian.raspberrypi.org` no longer serves Buster packages.
Tried several mirrors before finding that `archive.debian.org` still hosts Buster. Also needed
to bypass GPG signature validation since the archived keys had expired:
```bash
sudo apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true
sudo apt-get install -y --allow-unauthenticated hostapd dnsmasq
```

### Issue 4: hostapd was masked by systemd
After install, hostapd was automatically masked (disabled at system level) because it failed
on first start with no config. Had to unmask it before it could run:
```bash
sudo systemctl unmask hostapd
```

### Issue 5: wlan0 kept home WiFi IP instead of 192.168.4.1 (hotspot not visible)
After configuring hostapd, the iPhone couldn't see the network. The problem was that
`wpa_supplicant` was still running and holding `wlan0` connected to the home WiFi router
(`192.168.50.7`), preventing hostapd from taking over the interface as an AP.
Fixed by killing wpa_supplicant, flushing the interface, and restarting dhcpcd so it
applied the static IP from `dhcpcd.conf`:
```bash
sudo killall wpa_supplicant
sudo ip addr flush dev wlan0
sudo systemctl restart dhcpcd
sudo systemctl restart hostapd
```

### Issue 6: iPhone connected but got no IP (spinning indefinitely)
dnsmasq had started before `wlan0` had its static IP (`192.168.4.1`), so it bound to the
wrong interface state and wasn't serving DHCP properly. A simple restart after hostapd
was stable fixed it:
```bash
sudo systemctl restart dnsmasq
```
Then forget and rejoin the network on iPhone.

---

## Troubleshooting

**Network not visible on iPhone:**
```bash
sudo systemctl status hostapd
sudo systemctl restart hostapd
```

**iPhone connects but no IP assigned:**
```bash
sudo systemctl restart dnsmasq
# Then forget and rejoin on iPhone
```

**wlan0 still has home WiFi IP instead of 192.168.4.1:**
```bash
sudo killall wpa_supplicant
sudo ip addr flush dev wlan0
sudo systemctl restart dhcpcd
sudo systemctl restart hostapd
```

**Check connected devices:**
```bash
cat /var/lib/misc/dnsmasq.leases
```
