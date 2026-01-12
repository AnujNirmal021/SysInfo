📘 Installation Manual — System Info & Dashboard Tool (WSL + Windows)
This script (sysinfo_zenity.sh) is designed to run inside WSL (Ubuntu) and integrates with Windows for certain features (battery status, dashboard browser opening, etc).
Below are the exact prerequisites required for any new machine to run this tool successfully.

✅ Supported Environment

Windows 10/11
WSL 2
Ubuntu 20.04, 22.04, or 24.04 LTS (recommended)


🚀 Quick Start Summary
Component		Required?	Purpose
WSL (Ubuntu)		Yes		Runs the script and Linux tools
Zenity	Yes		GUI 		dialogs
Python 3		Yes		For charts, health check, dashboard
python3-psutil		Yes		System statistics
python3-plotly		Yes 		(optional but recommended) Interactive HTML dashboard
python3-matplotlib	Yes		PNG charts
wslu (wslview)		Yes		Opens images/HTML in Windows browser
Windows PowerShell	Yes		For battery WMI queries
Windows Python		No		Not used

🏗️ SECTION 1 — WSL (Ubuntu) Prerequisites
Open your Ubuntu (WSL) terminal and run every step below 👇:
1️⃣ Update system packages

sudo apt update
sudo apt upgrade -y

2️⃣ Install Zenity GUI toolkit

sudo apt install -y zenity

3️⃣ Install Python dependencies
These are required for RAM/Disk CPU/Net charts, Health Check, Dashboard.

sudo apt install -y python3 python3-pip python3-venv

4️⃣ Install system-provided libraries (safe on Ubuntu with PEP 668)
This avoids pip issues like “externally-managed-environment”.
(Referenced in PEP 668 documentation and Ubuntu behavior changes.)

sudo apt install -y python3-psutil python3-plotly python3-matplotlib

These packages exist in Ubuntu repos:

python3-psutil [stackoverflow.com]
python3-plotly [usm.uni-muenchen.de]
python3-matplotlib (default repo)


DO NOT use pip install plotly psutil unless inside a virtual environment — Ubuntu 23.04+ blocks it via PEP 668.
If you still want PyPI versions, create a venv:


python3 -m venv ~/.venvs/sysinfo
~/.venvs/sysinfo/bin/pip install plotly psutil matplotlib

5️⃣ Install wslu (for opening files in Windows)

sudo apt install -y wslu

This gives you:

wslview → opens PNG/HTML in Windows browser or Photos app

6️⃣ Install support tools

sudo apt install -y git sed awk df iproute2 procps

7️⃣ Make the script executable

chmod +x sysinfo_zenity.sh

8️⃣ Run the tool

./sysinfo_zenity.sh

🖥️ SECTION 2 — Windows PowerShell Prerequisites
The script calls Windows WMI to read battery information using:

powershell.exe -Command "Get-WmiObject Win32_Battery ..."

So ensure the following:
✔ No prerequisite installs needed
PowerShell comes preinstalled.
✔ WMI must be available
Works on:

Windows laptops (battery exists)
Windows tablets
Some hybrids

Will NOT work on:

Desktop PCs (no battery)
Some VMs (no battery hardware)

✔ wsl.exe integration must be enabled
Ensure this is ON in PowerShell (run as admin):

wsl --status

If WSL is disabled, enable it:


dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

🌐 SECTION 3 — Troubleshooting Guide
❗ Error: externally-managed-environment when installing Python packages
Caused by Ubuntu’s adoption of PEP 668.
Solution: use apt packages (recommended) or create a venv.

❗ Zenity window does not open / disappears
Common in WSL without GUI.
Fix:

sudo apt install -y zenity

If using WSL1 → prefer WSL2.

❗ PNG/HTML does not auto-open
Check if wslview is installed:

which wslview

Install if missing:

sudo apt install -y wslu

❗ No battery data shown
This is normal on:

Desktop PC
VM
WSL where Windows cannot expose battery


❗ Plotly dashboard does not open
Install both:

sudo apt install python3-plotly wslu

Then:

wslview /tmp/sys_dashboard.html

📦 SECTION 4 — GitHub Workflow (User Guide)
This is how ANY user can download and run your script from GitHub.
1️⃣ Clone the repo into WSL


git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>

2️⃣ Install prerequisites (from Section 1)
Run the required apt commands.
3️⃣ Make the script executable

chmod +x sysinfo_zenity.sh

4️⃣ Run

./sysinfo_zenity.sh

🧪 SECTION 5 — Optional: Windows Desktop Launcher
Create a .bat file on Desktop:


@echo off
wsl -e bash -lc "~/projects/sysinfo-zenity/sysinfo_zenity.sh"

Double‑click → runs the tool.

📘 SECTION 6 — Optional: Screenshots Integration in README
Store screenshots in: assets/screenshots/

![RAM Donut](assets/screenshots/ram_donut.png)
![CPU Line](assets/screenshots/cpu_line.png)
![Dashboard](assets/screenshots/dashboard.png)
