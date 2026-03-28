# Pi-hole Blocklist Collection

A curated collection of 52 blocklist sources used to populate Pi-hole's block list. Covers advertising, tracking/telemetry, malicious domains, phishing, scams, fake news, stalkerware, piracy, and more. All lists are sourced from well-maintained community and security projects and are regularly reviewed and updated.

> **Disclaimer:** This is a personal curated index of community blocklist sources. No blocklist is perfect. Review before deploying on production networks.

---

## Repository Contents

| File | Description |
|------|-------------|
| `blocklists.txt` | Plain text file containing all 52 blocklist URLs, one per line |
| `Import-PiHoleBlocklists.ps1` | PowerShell script to bulk import all lists into Pi-hole's gravity database |
| `import_pihole_blocklists.py` | Python script to bulk import all lists into Pi-hole's gravity database |

---

## Quick Start

### Option 1 — Import with PowerShell

Run this on your Pi-hole host. Requires PowerShell 7+ and `sqlite3` CLI.

```bash
sudo pwsh ./Import-PiHoleBlocklists.ps1
```

### Option 2 — Import with Python

Run this on your Pi-hole host. Requires Python 3.6+ and the `requests` library.

```bash
pip install requests
sudo python3 import_pihole_blocklists.py
```

Both scripts will:
- Download `blocklists.txt` directly from this repo
- Insert each URL into Pi-hole's gravity database
- Skip any URLs already present (safe to run multiple times)
- Run `pihole -g` automatically to update gravity when done

---

## Import Script Parameters

### PowerShell — `Import-PiHoleBlocklists.ps1`

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BlocklistUrl` | GitHub raw URL | URL to the remote `blocklists.txt` file |
| `-LocalFile` | _(none)_ | Path to a local `blocklists.txt` — skips download if provided |
| `-GravityDb` | `/etc/pihole/gravity.db` | Path to Pi-hole's gravity database |
| `-SkipGravityUpdate` | `false` | If set, skips running `pihole -g` after inserting |

**Examples:**

```powershell
# Default run
sudo pwsh ./Import-PiHoleBlocklists.ps1

# Use a local file
sudo pwsh ./Import-PiHoleBlocklists.ps1 -LocalFile ./blocklists.txt

# Import without updating gravity
sudo pwsh ./Import-PiHoleBlocklists.ps1 -SkipGravityUpdate
```

### Python — `import_pihole_blocklists.py`

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--blocklist-url` | GitHub raw URL | URL to the remote `blocklists.txt` file |
| `--local-file` | _(none)_ | Path to a local `blocklists.txt` — skips download if provided |
| `--gravity-db` | `/etc/pihole/gravity.db` | Path to Pi-hole's gravity database |
| `--skip-gravity-update` | `false` | If set, skips running `pihole -g` after inserting |

**Examples:**

```bash
# Default run
sudo python3 import_pihole_blocklists.py

# Use a local file
sudo python3 import_pihole_blocklists.py --local-file ./blocklists.txt

# Import without updating gravity
sudo python3 import_pihole_blocklists.py --skip-gravity-update
```

---

## Manual Setup (No Script)

To add lists manually via the Pi-hole admin panel:

1. Log into your Pi-hole admin panel at `http://<your-pihole-ip>/admin`
2. Navigate to **Group Management > Adlists**
3. Paste the raw URL of any list into the **Address** field
4. Add a comment/description if desired
5. Click **Add**
6. After adding all desired lists go to **Tools > Update Gravity** and click **Update**

---

## Blocklist Categories

| Category | Description |
|----------|-------------|
| **Advertising** | Ad servers, ad networks, and pop-up ad domains |
| **Tracking** | Telemetry, fingerprinting, and analytics domains |
| **Malicious** | Malware, ransomware, phishing, and scam domains |
| **Suspicious** | Spam, referrer spam, and high-risk domains |
| **Fake DNS / DynDNS** | Fake DNS providers and dynamic DNS abusers |
| **Piracy** | Anti-piracy DNS blocklist |
| **Fake News** | Known fake news domains |
| **Stalkerware** | Stalkerware and spyware indicator domains |
| **Device Trackers** | Platform-native trackers (Amazon, Apple, TikTok, Samsung, LG, Windows/Office) |
| **URL Shorteners** | URL shortener services used to obscure malicious links |
| **Encrypted DNS/VPN Bypass** | Domains used to circumvent DNS filtering |
| **Whitelist** | Approved domains excluded from blocking |

---

## Full Blocklist Sources

### Suspicious / Spam

| Source | URL |
|--------|-----|
| KADhosts | https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt |
| FadeMind Spam Extras | https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts |
| w3kbl | https://v.firebog.net/hosts/static/w3kbl.txt |
| Matomo Referrer Spam Blacklist | https://raw.githubusercontent.com/matomo-org/referrer-spam-blacklist/master/spammers.txt |
| Someone Who Cares Hosts Zero | https://someonewhocares.org/hosts/zero/hosts |
| RooneyMcNibNug SNAFU | https://raw.githubusercontent.com/RooneyMcNibNug/pihole-stuff/master/SNAFU.txt |

### Advertising

| Source | URL |
|--------|-----|
| AdAway | https://adaway.org/hosts.txt |
| AdGuard DNS | https://v.firebog.net/hosts/AdguardDNS.txt |
| Admiral | https://v.firebog.net/hosts/Admiral.txt |
| anudeepND Ad Servers | https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt |
| Easylist | https://v.firebog.net/hosts/Easylist.txt |
| MVPS Hosts (yoyo.org) | https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext |
| FadeMind Unchecky Ads | https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UnCheckyAds/hosts |
| bigdargon hostsVN | https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts |

### Tracking / Telemetry

| Source | URL |
|--------|-----|
| Easyprivacy | https://v.firebog.net/hosts/Easyprivacy.txt |
| Prigent Ads | https://v.firebog.net/hosts/Prigent-Ads.txt |
| FadeMind 2o7Net | https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts |
| WindowsSpyBlocker Spy | https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt |
| Amazon Tracker DNS Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.amazon.txt |
| Apple Tracker DNS Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.apple.txt |
| Windows/Office Tracker Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.winoffice.txt |
| Samsung Tracker DNS Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.samsung.txt |
| TikTok Fingerprinting Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.tiktok.txt |
| LG webOS Tracker DNS Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.lgwebos.txt |

### Malicious / Phishing / Scams

| Source | URL |
|--------|-----|
| DandelionSprout Anti-Malware | https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt |
| Prigent Crypto | https://v.firebog.net/hosts/Prigent-Crypto.txt |
| FadeMind Risk Extras | https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts |
| Phishing Army Extended | https://phishing.army/download/phishing_army_blocklist_extended.txt |
| Phishing Army Standard | https://phishing.army/download/phishing_army_blocklist.txt |
| NoTrack Malware | https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt |
| RPiList Malware | https://v.firebog.net/hosts/RPiList-Malware.txt |
| Spam404 Main Blacklist | https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt |
| AssoEchap Stalkerware Indicators | https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts |
| URLhaus Abuse.ch | https://urlhaus.abuse.ch/downloads/hostfile/ |
| CyberHost Malware | https://lists.cyberhost.uk/malware.txt |
| Malware Filter Phishing Hosts | https://malware-filter.gitlab.io/malware-filter/phishing-filter-hosts.txt |
| Prigent Malware | https://v.firebog.net/hosts/Prigent-Malware.txt |
| JarellIama Scam Blocklist | https://raw.githubusercontent.com/jarelllama/Scam-Blocklist/main/lists/wildcard_domains/scams.txt |
| RPiList Phishing | https://v.firebog.net/hosts/RPiList-Phishing.txt |

### Hagezi DNS Blocklists

| Source | URL |
|--------|-----|
| Fake DNS Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/fake.txt |
| Pop-Up Ads DNS Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/popupads.txt |
| Threat Intelligence Feeds | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.txt |
| Encrypted DNS/VPN/TOR Bypass | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/doh-vpn-proxy-bypass.txt |
| SafeSearch Not Supported | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/nosafesearch.txt |
| DynDNS Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/dyndns.txt |
| Badware Hoster DNS Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/hoster.txt |
| URL Shortener Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/urlshortener.txt |
| Spam TLDs Adblock | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/spam-tlds-adblock.txt |
| Anti-Piracy DNS Blocklist | https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/anti.piracy.txt |

### Other

| Source | URL |
|--------|-----|
| StevenBlack Unified Hosts | https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts |
| StevenBlack Fake News | https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts |
| anudeepND Whitelist | https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt |

---

## Maintenance

This list is reviewed and updated regularly as new sources are identified or existing sources become unmaintained. Check back for additions and removals.

---

## Credits

All blocklists are maintained by their respective authors and communities. This repo is a curated index of sources found to be effective. Full credit goes to the original maintainers of each list.
