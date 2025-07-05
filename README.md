# 🎮 Dead by Daylight Server Selector (via hosts file)

This PowerShell script allows you to **force matchmaking to specific regional servers** in *Dead by Daylight* by editing the Windows `hosts` file.

> ✅ This is useful if you want to avoid specific regions or always play on your preferred server (e.g., Europe, US East, etc.).

---

## 🧠 How it works

Dead by Daylight pings multiple AWS GameLift servers at startup to determine the best region based on latency.

By editing your `C:\Windows\System32\drivers\etc\hosts` file and blocking certain `gamelift-ping.*.api.aws` addresses (by mapping them to `0.0.0.0`), you can trick the game into only considering a subset of regions — effectively **forcing the server selection**.

This script makes that process **interactive and safe**, with a clean terminal menu and auto-launch.

---

## ⚙️ Features

- 🖥️ Command-line interface with interactive menu
- ✅ Select one or multiple servers to whitelist (force matchmaking there)
- 🛑 Reset option: unblock all servers (restore default behavior)
- 🧠 Clear confirmation before applying any changes
- 🗂️ Automatically backs up and modifies the `hosts` file
- 🚀 Automatically launches *Dead by Daylight* after applying your selection (via Steam)

---

## 🔒 Requirements

- Windows 10/11
- PowerShell (comes pre-installed)
- Must be **run as administrator** (to modify the `hosts` file)
- Steam installed, with *Dead by Daylight* owned and installed

---

## 🚀 Quick Start (One-liner)

To run the script directly from GitHub (no download needed):

```powershell
irm https://raw.githubusercontent.com/LED-N/dbd-server-selector/main/dbd_servers.ps1 | iex
