<!-- markdownlint-disable MD036 MD040 MD060 -->

# Pi-hole Blocklist Collection

A curated collection of 65 blocklist sources for Pi-hole. Covers advertising, tracking, telemetry, malicious domains, phishing, scams, fake news, stalkerware, piracy, CNAME cloaking, smart TV tracking, and more. All lists are sourced from well-maintained community and security projects.

> **Disclaimer:** This is a personal curated index of community blocklist sources. No blocklist is perfect. Review before deploying on production networks.

---

## Before You Begin

**What is a blocklist?**
A blocklist is a plain text file containing a list of domain names that should be blocked. Pi-hole downloads these files, reads every domain name in them, and adds those domains to its block database. When a device on your network tries to look up one of those domains, Pi-hole intercepts it and returns nothing, so the ad, tracker, or malicious content never loads.

**What is gravity?**
Gravity is Pi-hole's term for the process of downloading all your configured blocklists and compiling them into a single database it can query quickly. When you run `pihole -g` or click **Update Gravity** in the admin panel, Pi-hole is fetching fresh copies of every list and rebuilding that database. You need to update gravity after adding new lists for them to take effect.

**What is the gravity database?**
It is a file at `/etc/pihole/gravity.db` on your Pi-hole device. The import scripts in this folder write blocklist URLs directly into that database file. That is why they need to be run on the Pi-hole device itself, not on your personal computer.

---

## Repository Contents

| File | Description |
|------|-------------|
| `PiHoleListSources.txt` | Plain text file containing all source list URLs, one per line |
| `CountryGeoFencing.txt` | List of countries used to configure geo-fencing DNS blocks |
| `Build-CuratedBlocklist.ps1` | PowerShell script that downloads all source lists, extracts domains, sorts, and de-duplicates output |
| `CuratedBlackList.txt` | Generated blocklist output file produced by Build-CuratedBlocklist.ps1 |
| `CuratedWhitelist.txt` | Generated whitelist output file produced by Build-CuratedBlocklist.ps1 |
| `FailedSources.txt` | Generated run log file produced by Build-CuratedBlocklist.ps1 listing failed source URLs (can be blank) |
| `Import-PiHoleBlocklists.ps1` | PowerShell script to bulk import all lists into Pi-hole's gravity database |
| `import_pihole_blocklists.py` | Python script to bulk import all lists into Pi-hole's gravity database |

Note: The repository root includes `Remove-DuplicateCsvRows.ps1` for local cleanup of very large CSV exports. It removes column 1 and de-duplicates rows using original columns 2, 3, and 4 by default.
Local `.csv` files are ignored by Git via the root `.gitignore`.

---

## Quick Start

The two import scripts do the same thing — they read this repository's `PiHoleListSources.txt` file and add every URL in it to your Pi-hole. Choose whichever language you prefer or have available.

> **Important:** These scripts must be run on the Pi-hole device itself, not on your personal Windows or Mac computer. Connect to your Pi-hole over SSH first (see the Key Concepts section in the main [README](../README.md) if you are not sure how to do this).

### Option 1 — Import with PowerShell

**What you need first:**

- PowerShell 7 or later installed on your Pi-hole device
- The `sqlite3` command-line tool installed on your Pi-hole device

**Install PowerShell 7 on Raspberry Pi OS / Debian / Ubuntu:**

```bash
sudo apt-get update
sudo apt-get install -y wget apt-transport-https
wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
```

**Install sqlite3:**

```bash
sudo apt-get install -y sqlite3
```

**Run the import script:**

```bash
sudo pwsh ./Import-PiHoleBlocklists.ps1
```

### Option 2 — Import with Python

**What you need first:**

- Python 3.6 or later (check your version by running `python3 --version`)
- The `requests` library

**Install the requests library:**

```bash
pip3 install requests
```

If `pip3` is not found, install it first:

```bash
sudo apt-get install -y python3-pip
```

**Run the import script:**

```bash
sudo python3 import_pihole_blocklists.py
```

**What both scripts do:**

- Download `PiHoleListSources.txt` directly from this GitHub repository
- Insert each URL into Pi-hole's gravity database
- Skip any URLs that are already in the database (safe to run more than once)
- Run `pihole -g` automatically at the end to update gravity and activate the new lists

**How long does it take?**
The import itself takes a few seconds. The gravity update at the end can take 1 to 10 minutes depending on your Pi-hole hardware and internet speed. You will see progress messages as it runs.

---

## Build a Curated Domain List

Use `Build-CuratedBlocklist.ps1` when you want de-duplicated domain files generated from all URLs listed in `PiHoleListSources.txt`.

What it does:

- Reads source URLs from GitHub or a local source file
- Downloads each source list with retry logic
- Extracts domains from common hosts and adblock style formats
- Separates blocklist and whitelist sources automatically
- Sorts and de-duplicates domains for each output
- Writes output to `CuratedBlackList.txt` using atomic replace
- Writes whitelist output to `CuratedWhitelist.txt` using atomic replace
- Always writes `FailedSources.txt` for the run (blank when there are no failures)
- Deletes previous generated output files before each run and verifies deletion on screen
- Shows download progress counters such as `1 of 56`
- Optionally stages, commits, and pushes all generated output files to GitHub (`CuratedBlackList.txt`, `CuratedWhitelist.txt`, and `FailedSources.txt`)

Examples:

```powershell
# Build curated output only
.\Build-CuratedBlocklist.ps1

# Strict mode plus failed source log
.\Build-CuratedBlocklist.ps1 -FailOnSourceError -FailedSourcesLogFile .\FailedSources.txt

# Build and push to GitHub
.\Build-CuratedBlocklist.ps1

# Disable push for a local-only run
.\Build-CuratedBlocklist.ps1 -DisableGitPush
```

---

## Import Script Parameters

### PowerShell — `Import-PiHoleBlocklists.ps1`

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BlocklistUrl` | GitHub raw URL | URL to the remote `PiHoleListSources.txt` file |
| `-LocalFile` | _(none)_ | Path to a local `PiHoleListSources.txt` — skips download if provided |
| `-GravityDb` | `/etc/pihole/gravity.db` | Path to Pi-hole's gravity database |
| `-SkipGravityUpdate` | `false` | If set, skips running `pihole -g` after inserting |

**Examples:**

```powershell
# Default run
sudo pwsh ./Import-PiHoleBlocklists.ps1

# Use a local file
sudo pwsh ./Import-PiHoleBlocklists.ps1 -LocalFile ./PiHoleListSources.txt

# Import without updating gravity
sudo pwsh ./Import-PiHoleBlocklists.ps1 -SkipGravityUpdate
```

### Python — `import_pihole_blocklists.py`

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--blocklist-url` | GitHub raw URL | URL to the remote `PiHoleListSources.txt` file |
| `--local-file` | _(none)_ | Path to a local `PiHoleListSources.txt` — skips download if provided |
| `--gravity-db` | `/etc/pihole/gravity.db` | Path to Pi-hole's gravity database |
| `--skip-gravity-update` | `false` | If set, skips running `pihole -g` after inserting |

**Examples:**

```bash
# Default run
sudo python3 import_pihole_blocklists.py

# Use a local file
sudo python3 import_pihole_blocklists.py --local-file ./PiHoleListSources.txt

# Import without updating gravity
sudo python3 import_pihole_blocklists.py --skip-gravity-update
```

---

## Manual Setup (No Script)

If you prefer not to run a script, you can add lists manually through the Pi-hole admin panel. This takes longer but requires no technical knowledge beyond clicking through a web interface.

**Step 1 — Open the admin panel**

Open a browser on any device on your network and go to:

```
http://<your-pihole-ip>/admin
```

Replace `<your-pihole-ip>` with your Pi-hole's actual IP address. Log in with your Pi-hole password.

**Step 2 — Navigate to Adlists**

In the left menu, click **Group Management**, then click **Adlists**.

**Step 3 — Add a list**

Open `PiHoleListSources.txt` from this repository. Copy one URL, paste it into the **Address** field in the admin panel, optionally add a comment to remind yourself what the list is for, and click **Add**. Repeat for each URL you want to add.

**Step 4 — Update Gravity**

After adding all your lists, go to **Tools** in the left menu and click **Update Gravity**. Then click the **Update** button. Pi-hole will download all the lists and rebuild its block database. This step is required — the lists will not be active until gravity is updated.

Progress will be shown on screen. When you see a green success message, your new lists are active.

---

## Blocklist Categories

| Category | Description |
|----------|-------------|
| **Advertising** | Ad servers, ad networks, and pop-up ad domains |
| **Tracking** | Telemetry, fingerprinting, analytics, and CNAME cloaking domains |
| **Malicious** | Malware, ransomware, phishing, and scam domains |
| **Suspicious** | Spam, referrer spam, and high-risk domains |
| **Fake DNS / DynDNS** | Fake DNS providers and dynamic DNS abusers |
| **Piracy** | Anti-piracy DNS blocklist |
| **Fake News** | Known fake news domains |
| **Stalkerware** | Stalkerware and spyware indicator domains |
| **Device Trackers** | Platform-native trackers (Amazon, Apple, TikTok, Samsung, LG, Windows/Office) |
| **Smart TV / IoT** | Broad smart TV tracking and telemetry across all brands |
| **URL Shorteners** | URL shortener services used to obscure malicious links |
| **Encrypted DNS/VPN Bypass** | Domains used to circumvent DNS filtering |
| **OISD** | Comprehensive all-in-one blocklist covering ads, tracking, and malware |
| **Whitelist** | Approved domains excluded from blocking |

---

## Full Blocklist Sources

### Suspicious / Spam

| Source | URL |
|--------|-----|
| KADhosts | <https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt> |
| FadeMind Spam Extras | <https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts> |
| w3kbl | <https://v.firebog.net/hosts/static/w3kbl.txt> |
| Matomo Referrer Spam Blacklist | <https://raw.githubusercontent.com/matomo-org/referrer-spam-blacklist/master/spammers.txt> |
| Someone Who Cares Hosts Zero | <https://someonewhocares.org/hosts/zero/hosts> |
| RooneyMcNibNug SNAFU | <https://raw.githubusercontent.com/RooneyMcNibNug/pihole-stuff/master/SNAFU.txt> |

### Advertising

| Source | URL |
|--------|-----|
| AdAway | <https://adaway.org/hosts.txt> |
| AdGuard DNS | <https://v.firebog.net/hosts/AdguardDNS.txt> |
| Admiral | <https://v.firebog.net/hosts/Admiral.txt> |
| anudeepND Ad Servers | <https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt> |
| Easylist | <https://v.firebog.net/hosts/Easylist.txt> |
| MVPS Hosts (yoyo.org) | <https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext> |
| FadeMind Unchecky Ads | <https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UnCheckyAds/hosts> |
| bigdargon hostsVN | <https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts> |
| Disconnect.me Simple Ad | <https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt> |

### Tracking / Telemetry

| Source | URL |
|--------|-----|
| Easyprivacy | <https://v.firebog.net/hosts/Easyprivacy.txt> |
| Prigent Ads | <https://v.firebog.net/hosts/Prigent-Ads.txt> |
| FadeMind 2o7Net | <https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts> |
| WindowsSpyBlocker Spy | <https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt> |
| NextDNS CNAME Cloaking Blocklist | <https://raw.githubusercontent.com/nextdns/cname-cloaking-blocklist/master/domains> |
| Amazon Tracker DNS Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.amazon.txt> |
| Apple Tracker DNS Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.apple.txt> |
| Windows/Office Tracker Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.winoffice.txt> |
| Samsung Tracker DNS Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.samsung.txt> |
| TikTok Fingerprinting Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.tiktok.txt> |
| LG webOS Tracker DNS Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/native.lgwebos.txt> |

### Malicious / Phishing / Scams

| Source | URL |
|--------|-----|
| DandelionSprout Anti-Malware | <https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt> |
| Prigent Crypto | <https://v.firebog.net/hosts/Prigent-Crypto.txt> |
| FadeMind Risk Extras | <https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts> |
| Phishing Army Extended | <https://phishing.army/download/phishing_army_blocklist_extended.txt> |
| Phishing Army Standard | <https://phishing.army/download/phishing_army_blocklist.txt> |
| NoTrack Malware | <https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt> |
| RPiList Malware | <https://v.firebog.net/hosts/RPiList-Malware.txt> |
| Spam404 Main Blacklist | <https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt> |
| AssoEchap Stalkerware Indicators | <https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts> |
| URLhaus Abuse.ch | <https://urlhaus.abuse.ch/downloads/hostfile/> |
| CyberHost Malware | <https://lists.cyberhost.uk/malware.txt> |
| Malware Filter Phishing Hosts | <https://malware-filter.gitlab.io/malware-filter/phishing-filter-hosts.txt> |
| Prigent Malware | <https://v.firebog.net/hosts/Prigent-Malware.txt> |
| JarellIama Scam Blocklist | <https://raw.githubusercontent.com/jarelllama/Scam-Blocklist/main/lists/wildcard_domains/scams.txt> |
| RPiList Phishing | <https://v.firebog.net/hosts/RPiList-Phishing.txt> |

### Hagezi DNS Blocklists

| Source | URL |
|--------|-----|
| Hagezi Pro | <https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt> |
| Fake DNS Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/fake.txt> |
| Pop-Up Ads DNS Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/popupads.txt> |
| Threat Intelligence Feeds | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.txt> |
| Encrypted DNS/VPN/TOR Bypass | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/doh-vpn-proxy-bypass.txt> |
| SafeSearch Not Supported | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/nosafesearch.txt> |
| DynDNS Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/dyndns.txt> |
| Badware Hoster DNS Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/hoster.txt> |
| URL Shortener Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/urlshortener.txt> |
| Spam TLDs Adblock | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/spam-tlds-adblock.txt> |
| Anti-Piracy DNS Blocklist | <https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/anti.piracy.txt> |

### OISD

| Source | URL |
|--------|-----|
| OISD Big | <https://big.oisd.nl/> |

### Smart TV / IoT

| Source | URL |
|--------|-----|
| Perflyst SmartTV | <https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt> |

### Other

| Source | URL |
|--------|-----|
| StevenBlack Unified Hosts | <https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts> |
| StevenBlack Fake News | <https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts> |
| anudeepND Whitelist | <https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt> |

---

## Maintenance

This list is reviewed and updated regularly as new sources are identified or existing sources become unmaintained. Check back for additions and removals.

---

## Credits

All blocklists in this collection are maintained by their respective authors and communities. This repository is a curated index of sources found to be effective and well-maintained. Full credit goes to the original maintainers of each list.

Notable projects included in this collection:

- [anudeepND](https://github.com/anudeepND) — Ad server and whitelist collections
- [Hagezi](https://github.com/hagezi/dns-blocklists) — Comprehensive multi-purpose DNS blocklists
- [OISD](https://oisd.nl) — All-in-one blocklist
- [StevenBlack](https://github.com/StevenBlack/hosts) — Unified hosts file
- [Phishing Army](https://phishing.army) — Phishing domain blocklist
- [URLhaus / abuse.ch](https://urlhaus.abuse.ch) — Malware URL tracking
- [DandelionSprout](https://github.com/DandelionSprout) — Anti-malware list
- [Firebog](https://firebog.net) — Curated Pi-hole blocklist index
- [AssoEchap](https://github.com/AssoEchap/stalkerware-indicators) — Stalkerware indicators
- [NextDNS](https://github.com/nextdns/cname-cloaking-blocklist) — CNAME cloaking blocklist
- [crazy-max / WindowsSpyBlocker](https://github.com/crazy-max/WindowsSpyBlocker) — Windows telemetry blocklist
- [Spam404](https://github.com/Spam404/lists) — Scam and fraud domain list
- [JarellIama](https://github.com/jarelllama/Scam-Blocklist) — Scam domain blocklist
- [Perflyst](https://github.com/Perflyst/PiHoleBlocklist) — Smart TV blocklist
- [bigdargon](https://github.com/bigdargon/hostsVN) — Vietnamese ad hosts
- [RooneyMcNibNug](https://github.com/RooneyMcNibNug/pihole-stuff) — SNAFU blocklist
- [PolishFiltersTeam](https://github.com/PolishFiltersTeam/KADhosts) — KADhosts
- [FadeMind](https://github.com/FadeMind/hosts.extras) — Hosts extras collection
- [Matomo](https://github.com/matomo-org/referrer-spam-blacklist) — Referrer spam blacklist
- [Disconnect.me](https://disconnect.me) — Simple ad and tracking lists
- [CyberHost](https://lists.cyberhost.uk) — Malware list
- [malware-filter](https://gitlab.com/malware-filter) — Phishing filter hosts

<!-- markdownlint-enable MD036 MD040 MD060 -->
