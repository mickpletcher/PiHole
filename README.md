# Pi-hole Configuration & Blocklists

This repository contains a curated collection of blocklists and tools to help you get the most out of Pi-hole — a free, open-source tool that blocks ads, trackers, and malicious websites across your entire home network at the DNS level. That means every device on your network — phones, tablets, smart TVs, laptops — gets protected automatically without installing anything on each device.

If you are new to Pi-hole, think of it as a filter that sits between your devices and the internet. When a device tries to connect to a known ad or tracking domain, Pi-hole intercepts that request and blocks it before it ever reaches your device.

---

## What Is In This Repository

| Folder / File | What It Contains |
|---------------|-----------------|
| `Blocklists/` | A collection of 57 blocklist sources, import scripts, and detailed setup instructions |
| `Blocklists/README.md` | Step-by-step instructions for adding the blocklists to your Pi-hole |
| `Blocklists/blocklists.txt` | A plain text file with all 57 blocklist URLs, one per line |
| `Blocklists/Import-PiHoleBlocklists.ps1` | A PowerShell script that automatically adds all blocklists to Pi-hole |
| `Blocklists/import_pihole_blocklists.py` | A Python script that does the same thing as above |

---

## Getting Started

**Step 1 — Install Pi-hole**

If you have not installed Pi-hole yet, follow the official installation guide at https://docs.pi-hole.net. Pi-hole runs on a Raspberry Pi or any Linux machine on your network.

**Step 2 — Add the Blocklists**

Once Pi-hole is installed, follow the instructions in [Blocklists/README.md](Blocklists/README.md) to add the blocklist collection to your Pi-hole. This is where the actual blocking power comes from.

**Step 3 — Set Up Automation**

Follow the tips below to keep your Pi-hole running smoothly with minimal ongoing maintenance.

---

## Tips for a Well-Maintained Pi-hole

---

### Tip 1 — Keep Your Blocklists Fresh Automatically

Pi-hole's blocklists do not update themselves by default. New ad, tracking, and malicious domains are added to the internet every day, so if your lists never update, your protection gradually becomes less effective over time.

The fix is to schedule an automatic update using a tool called **cron** — a built-in Linux feature that runs commands on a timer, like a built-in task scheduler.

**How to set it up:**

First, connect to your Pi-hole over SSH. If you are on Windows, open PowerShell and type:

```bash
ssh pi@<your-pihole-ip>
```

Replace `<your-pihole-ip>` with the actual IP address of your Pi-hole (for example `192.168.1.100`). You can find this in your router's admin panel under connected devices.

Once connected, open the cron scheduler:

```bash
crontab -e
```

If it asks you to choose an editor, type `1` and press Enter to select nano (the simplest option).

Paste these two lines at the very bottom of the file:

```
0 2 */3 * * pihole -g >> /var/log/pihole-gravity.log 2>&1
0 3 */3 * * pihole -up >> /var/log/pihole-update.log 2>&1
```

Save and exit by pressing `Ctrl+X`, then `Y`, then `Enter`.

**What this does:** Every 3 days at 2am, Pi-hole downloads fresh copies of all your blocklists. At 3am it checks for and installs any Pi-hole software updates.

**To verify it saved correctly:**

```bash
crontab -l
```

You should see both lines printed back to the screen.

---

### Tip 2 — Keep the Pi-hole Software Up to Date

Pi-hole regularly releases updates with bug fixes and security improvements. In addition to the automatic update scheduled above, you can run an update manually at any time by connecting over SSH and running:

```bash
pihole -up
```

To check whether an update ran successfully, view the log:

```bash
cat /var/log/pihole-update.log
```

---

### Tip 3 — Use a Whitelist

Occasionally a blocklist will accidentally block a website you actually want to use. This is called a false positive. When something on your network suddenly stops working, Pi-hole is often the cause.

**How to fix a blocked site:**

1. Log into the Pi-hole admin panel in your browser at `http://<your-pihole-ip>/admin`
2. Click **Query Log** in the left menu
3. Look for the domain that is being blocked (it will show in red)
4. Click the domain and select **Whitelist** to allow it

The anudeepND whitelist included in this collection pre-approves many commonly blocked legitimate domains so you should encounter fewer false positives out of the box.

---

### Tip 4 — Review Your Query Log Occasionally

The Pi-hole admin panel shows a live log of every DNS request made by every device on your network. This is useful for two things: spotting false positives as described above, and noticing unusual traffic from devices that should not be making network requests (smart TVs, IoT devices, etc.).

To access it:
1. Open your browser and go to `http://<your-pihole-ip>/admin`
2. Click **Query Log** in the left menu

---

### Tip 5 — Do Not Add Too Many Blocklists

It might seem like more blocklists equals more protection, but there is a point of diminishing returns. Too many overlapping lists can slow down Pi-hole's gravity update process and use more memory on your device without meaningfully improving coverage.

The 57 lists in this collection have been carefully selected to give broad coverage across ads, tracking, malware, and other threats while avoiding excessive overlap. Stick with what is here unless you have a specific need for something additional.

---

### Tip 6 — Give Pi-hole a Static IP Address

Pi-hole needs to always be reachable at the same IP address on your network. If your router assigns it a different IP address after a reboot, all devices on your network will lose internet access until the DNS settings are updated.

**The easiest fix** is to log into your router's admin panel and set up a DHCP reservation for your Pi-hole. This tells your router to always give Pi-hole the same IP address. The exact steps vary by router brand — search for "DHCP reservation" plus your router model if you are unsure how to do this.

---

### Tip 7 — Run a Second Pi-hole as a Backup

Pi-hole handles DNS for your entire network. If it goes offline for any reason — a crash, a reboot, a failed update — every device on your network will lose internet access until it comes back up.

The solution is to run a second Pi-hole on a separate device and configure your router to use it as a backup DNS server. Most routers have a Primary DNS and Secondary DNS field. Set Primary to your main Pi-hole and Secondary to your backup. If the primary goes down, devices automatically fail over to the backup.

---

### Tip 8 — Set Up a Health Check Alert

You can set up an automated check that notifies you if Pi-hole stops responding. Pi-hole has a built-in status endpoint you can use to check if it is healthy:

```
http://<pihole-ip>/admin/api.php?summary
```

Open that URL in your browser while Pi-hole is running. If it is healthy, you will see a page full of statistics in text format. If you get an error or a blank page, something is wrong.

For automatic alerting, tools like **UptimeRobot** (free, no technical setup required) can monitor that URL every few minutes and send you an email or phone notification if it goes down. Simply create a free account at https://uptimerobot.com, add a new monitor pointing to the URL above, and enter your notification email. No coding required.

---

## Credits

All blocklists are maintained by their respective authors and communities. This repository is a curated index of sources found to be effective. Full credit goes to the original maintainers of each list.
