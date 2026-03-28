# Pi-hole Blocklist Collection

A curated collection of 52 blocklist sources used to populate Pi-hole's block list. Covers advertising, tracking/telemetry, malicious domains, phishing, scams, fake news, stalkerware, piracy, and more. All lists are sourced from well-maintained community and security projects and are regularly reviewed and updated.

---

## Categories

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

## Blocklist Sources

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

## How to Add These Lists to Pi-hole

1. Log into your Pi-hole admin panel (`http://<your-pihole-ip>/admin`)
2. Navigate to **Group Management > Adlists**
3. Paste the raw URL of any list from the tables above into the **Address** field
4. Add a comment/description if desired
5. Click **Add**
6. After adding all desired lists, go to **Tools > Update Gravity** and click **Update**

To add all lists at once via the Pi-hole CLI:

```bash
sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('<URL>', 1, '<comment>');"
pihole -g
```

Replace `<URL>` and `<comment>` with the appropriate values for each list, then run `pihole -g` once after all inserts to update gravity.

---

## Maintenance

This list is reviewed and updated regularly as new sources are identified or existing sources become unmaintained. Check back for additions and removals.

---

## Credits

All blocklists are maintained by their respective authors and communities. This repo is simply a curated index of sources found to be effective. Credit goes to the original maintainers of each list.
