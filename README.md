# Pi-hole Configuration & Blocklists

A personal Pi-hole configuration repository containing a curated collection of blocklists, import scripts, and automation tips for running a well-maintained network-wide ad and threat blocker.

---

## Repository Structure

| Folder / File | Description |
|---------------|-------------|
| `Blocklists/` | Blocklist URLs, import scripts, and setup instructions |
| `Blocklists/README.md` | Full documentation for the blocklist collection |
| `Blocklists/blocklists.txt` | All 57 blocklist URLs in plain text, one per line |
| `Blocklists/Import-PiHoleBlocklists.ps1` | PowerShell import script |
| `Blocklists/import_pihole_blocklists.py` | Python import script |

---

## Getting Started

1. Install Pi-hole on your network — see the official docs at https://docs.pi-hole.net
2. Clone or download this repository
3. Follow the instructions in [Blocklists/README.md](Blocklists/README.md) to import the blocklist collection into your Pi-hole

---

## Tips for a Well-Maintained Pi-hole

### Keep Your Blocklists Fresh

Pi-hole's blocklists do not update themselves by default. New malicious, tracking, and ad domains are added to upstream lists daily. Schedule an automatic gravity update so your protection stays current without any manual effort:

```bash
crontab -e
```

Add these two lines:

```
0 2 */3 * * pihole -g >> /var/log/pihole-gravity.log 2>&1
0 3 */3 * * pihole -up >> /var/log/pihole-update.log 2>&1
```

This runs a gravity update and a Pi-hole software update every 3 days. See [Blocklists/README.md](Blocklists/README.md) for full instructions.

### Use a Whitelist

Aggressive blocklists occasionally block legitimate domains. Keep a whitelist handy and add domains to it when something on your network stops working unexpectedly. The anudeepND whitelist included in this collection is a good starting point.

### Review Your Query Log

The Pi-hole admin panel at `http://<your-pihole-ip>/admin` shows a live query log. Reviewing it occasionally helps you spot blocked domains that shouldn't be blocked, as well as unexpected traffic from devices on your network.

### Don't Overload Gravity

More lists is not always better. Too many overlapping lists slow down gravity updates and increase memory usage without meaningfully improving coverage. The 57 lists in this collection have been curated to balance broad coverage with minimal redundancy.

### Keep Pi-hole on a Static IP

Assign a static IP to your Pi-hole host either via your router's DHCP reservation settings or directly on the Pi-hole host itself. If the IP changes, all devices on your network will lose DNS resolution until it is updated.

### Run a Backup Pi-hole

If Pi-hole goes down, nothing on your network can resolve DNS. Consider running a second Pi-hole instance as a fallback. Point your router's secondary DNS at the backup so devices fail over automatically.

---

## Credits

All blocklists are maintained by their respective authors and communities. This repo is a curated index of sources found to be effective. Full credit goes to the original maintainers of each list.
