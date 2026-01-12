
#!/usr/bin/env bash
# sysinfo_zenity.sh — Single-file Zenity GUI System Info
# Author: Anuj
# Date: 2026-01-09
#bash script file

#PYTHON="$HOME/.venvs/sysinfo/bin/python"
#[[ -x "$PYTHON" ]] || PYTHON="python3"

set -Eeuo pipefail
IFS=$'\n\t'

# ---------- Helpers ----------
die() { echo "Error: $*" >&2; exit 1; }
tmpfile() { mktemp -t sysinfo.XXXXXX; }

require() {
  local missing=()
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
  if ((${#missing[@]})); then
    zenity --error --title="Missing dependencies" --width=400 \
      --text="Please install:\n${missing[*]}" || true
    die "Missing: ${missing[*]}"
  fi
}

# ---------- Section collectors ----------

live_monitor() {
  (
    while true; do
      echo "CPU: $(top -bn1 | awk '/Cpu/ {print $2}')%"
      echo "RAM: $(free -h | awk '/Mem:/ {print $3 "/" $2}')"
      echo "----"
      sleep 1
    done
  ) | zenity --text-info --title="Live Monitor" --width=600 --height=400
}

sec_overview() {
  # Read OS info from /etc/os-release (standardized key/value file)
  # Avoid 'source' for safety; parse PRETTY_NAME robustly.
  local os="Unknown"
  if [[ -r /etc/os-release ]]; then
    os=$(awk -F= '/^PRETTY_NAME=/{v=$2; gsub(/^"|"$/, "", v); print v}' /etc/os-release)
  fi
  # Kernel & uptime
  local kernel; kernel=$(uname -sr)
  local uptime_readable; uptime_readable=$(uptime -p || true)
  local boot_time; boot_time=$(uptime -s || true)

  cat <<EOF
=== Overview ===
OS          	: 	${os}
Kernel      	: 	${kernel}
Uptime      	: 	${uptime_readable}
Boot time   	: 	${boot_time}
Hostname    	: 	$(hostname)
Architecture	: 	$(uname -m)
EOF
}

sec_cpu() {
  local model cores
  model=$(grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //')
  cores=$(command -v nproc >/dev/null 2>&1 && nproc || grep -c '^processor' /proc/cpuinfo)
  cat <<EOF
=== CPU ===
Model 	:	 ${model:-unknown}
Cores 	: 	${cores:-unknown}
$(command -v lscpu >/dev/null 2>&1 && { echo; lscpu; } || true)
EOF
}

sec_memory() {
  cat <<EOF
=== Memory ===
$(free -h || true)

From /proc/meminfo:
$(grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree' /proc/meminfo)
EOF
}

sec_modules() {
  cat <<EOF
=== Loaded Kernel Modules ===
$(lsmod)
EOF
}

sec_disks() {
  cat <<EOF
=== Disks & Filesystems ===
# Block devices:
$(command -v lsblk >/dev/null 2>&1 && lsblk -f -o NAME,FSTYPE,SIZE,MOUNTPOINT || echo "lsblk not available")

# Mounted filesystems:
$(df -hT | awk 'NR==1 || $2!="tmpfs" {print}')
EOF
}

sec_power() {
  local output
  output=$(powershell.exe -Command "Get-WmiObject Win32_Battery | Format-List *" 2>/dev/null)

  # Convert CRLF → LF for Zenity formatting
  output=$(echo "$output" | sed 's/\r$//')

  cat <<EOF
=== Windows Battery Information ===
$output
EOF
}

sec_network() {
  cat <<EOF
=== Network ===
# Interfaces (brief):
$(ip -brief addr 2>/dev/null || echo "ip command not available")

# Default route:
$(ip route 2>/dev/null | grep -E '^default' || echo "ip route not available")

# DNS (resolv.conf):
$(grep -E '^nameserver' /etc/resolv.conf 2>/dev/null || echo "No nameservers found")
EOF
}


sec_gpu() {
  cat <<EOF
=== GPU / Graphics ===
$(lspci | grep -i 'vga\|3d\|display' || echo "GPU information not available")
EOF
}

sec_processes() {
  cat <<EOF
=== Top Processes (by CPU) ===
$(ps -eo pid,comm,user,%cpu,%mem --sort=-%cpu | head -n 15)
EOF
}

sec_services() {
  if command -v systemctl >/dev/null 2>&1; then
    cat <<EOF
=== Running systemd services ===
$(systemctl list-units --type=service --state=running --no-pager)
EOF
  else
    echo "systemctl not available (non-systemd or minimal environment)"
  fi
}

sec_devices() {
  cat <<EOF
=== Devices ===
# PCI:
$(command -v lspci >/dev/null 2>&1 && lspci || echo "lspci not available")

# USB:
$(command -v lsusb >/dev/null 2>&1 && lsusb || echo "lsusb not available")
EOF
}

# Build a full report
build_full_report() {
  {
    sec_live_monitor
    echo
    sec_overview
    echo
    sec_cpu
    echo
    sec_memory
    echo
    sec_modules
    echo
    sec_disks
    echo
    sec_power
    echo    
    sec_network
    echo
    sec_gpu
    echo
    sec_processes
    echo
    sec_services
    echo
    sec_devices
  }
}

chart_ram_matplotlib() {
python3 - <<'PY'
import matplotlib
matplotlib.use('Agg')  # headless backend
import matplotlib.pyplot as plt
import psutil

vm = psutil.virtual_memory()
used = vm.used; free = vm.available
used_pct = vm.percent

# Nice palette
used_color = '#e15759'   # red
free_color = '#59a14f'   # green

def format_gib(x): return f"{x/1024/1024/1024:.2f} GiB"

fig, ax = plt.subplots(figsize=(7.5, 7.5))
wedges, texts = ax.pie(
    [used, free],
    colors=[used_color, free_color],
    startangle=90,
    wedgeprops=dict(width=0.38, edgecolor='white')
)

# Center label
ax.text(0, 0, f"{used_pct:.0f}%\nUsed",
        ha='center', va='center', fontsize=24, fontweight='bold')

# Legend box
ax.legend(
    [f"Used: {format_gib(used)}", f"Free: {format_gib(free)}"],
    loc='lower center', bbox_to_anchor=(0.5, -0.05), ncol=2,
    frameon=False, fontsize=12
)

ax.set_title("RAM Usage", fontsize=18, pad=16)
ax.axis('equal')
plt.tight_layout()
plt.savefig('/tmp/viz_ram.png', dpi=150)
PY
wslview /tmp/viz_ram.png 2>/dev/null || xdg-open /tmp/viz_ram.png 2>/dev/null \
|| zenity --info --text="Saved: /tmp/viz_ram.png" --width=320
}


chart_disk_matplotlib() {
  # Temporarily use space as separator for this read
  local IFS=' '
  read -r USED FREE <<< "$(df -B1 --output=used,avail / | tail -1 | awk '{print $1, $2}')"
  # Restore IFS for the rest of the script (optional if IFS is globally set earlier)
  IFS=$'\n\t'

python3 - <<PY
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt

used = int("${USED}")
free = int("${FREE}")

def gib(x): return x/1024/1024/1024
used_pct = 100.0 * used / (used + free)
colors = ['#4e79a7', '#f28e2b']  # blue, orange

fig, ax = plt.subplots(figsize=(7.5,7.5))
ax.pie([used, free], colors=colors, startangle=90,
       wedgeprops=dict(width=0.38, edgecolor='white'))

ax.text(0, 0, f"{used_pct:.0f}%\nUsed", ha='center', va='center',
        fontsize=24, fontweight='bold')

ax.legend([f"Used: {gib(used):.2f} GiB", f"Free: {gib(free):.2f} GiB"],
          loc='lower center', bbox_to_anchor=(0.5, -0.05), ncol=2,
          frameon=False, fontsize=12)

ax.set_title("Disk Usage (/) — Donut", fontsize=18, pad=16)
ax.axis('equal'); plt.tight_layout()
plt.savefig('/tmp/viz_disk.png', dpi=150)
PY

  wslview /tmp/viz_disk.png 2>/dev/null || xdg-open /tmp/viz_disk.png 2>/dev/null \
  || zenity --info --text="Saved: /tmp/viz_disk.png" --width=320
}

chart_cpu_line_matplotlib() {
python3 - <<'PY'
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import psutil, time

samples = []
for _ in range(30):
    samples.append(psutil.cpu_percent(interval=1))
t = list(range(1, len(samples)+1))
avg = sum(samples)/len(samples)

fig, ax = plt.subplots(figsize=(9,5.5))
ax.plot(t, samples, color='#4e79a7', lw=2)
ax.fill_between(t, samples, [0]*len(samples), color='#4e79a7', alpha=0.15)
ax.axhline(avg, color='#e15759', ls='--', lw=1.5, label=f'Avg: {avg:.1f}%')

# Max point annotation
mx = max(samples); ix = samples.index(mx) + 1
ax.scatter([ix],[mx], color='#e15759', zorder=3)
ax.annotate(f"Max {mx:.1f}%", xy=(ix, mx), xytext=(ix+1, mx+5),
            arrowprops=dict(arrowstyle='->', color='#e15759'),
            fontsize=11)

ax.set_title("CPU Usage (last 30s)", fontsize=16, pad=10)
ax.set_xlabel("Seconds"); ax.set_ylabel("CPU %")
ax.set_ylim(0, 100); ax.grid(alpha=0.25); ax.legend(frameon=False)
plt.tight_layout()
plt.savefig('/tmp/viz_cpu.png', dpi=150)
PY
wslview /tmp/viz_cpu.png 2>/dev/null || xdg-open /tmp/viz_cpu.png 2>/dev/null \
|| zenity --info --text="Saved: /tmp/viz_cpu.png" --width=320
}

chart_net_bars_matplotlib() {
python3 - <<'PY'
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
import psutil, time

# Measure 1 second delta
a = psutil.net_io_counters(pernic=True)
time.sleep(1)
b = psutil.net_io_counters(pernic=True)

data = []
for nic in a:
    if nic in b:
        rx = b[nic].bytes_recv - a[nic].bytes_recv
        tx = b[nic].bytes_sent - a[nic].bytes_sent
        total = rx + tx
        data.append((nic, total, rx, tx))

# Sort by total throughput and pick top 5
data.sort(key=lambda x: x[1], reverse=True)
top = data[:5]

labels = [d[0] for d in top]
rx = [d[2]/1024 for d in top]  # KiB/s approx
tx = [d[3]/1024 for d in top]
x = range(len(labels))

fig, ax = plt.subplots(figsize=(9,5.5))
ax.bar(x, rx, color='#59a14f', label='Rx KiB/s')
ax.bar(x, tx, bottom=rx, color='#f28e2b', label='Tx KiB/s')
ax.set_xticks(x); ax.set_xticklabels(labels, rotation=15, ha='right')

ax.set_title("Network Throughput (Δ over 1s)", fontsize=16, pad=10)
ax.set_ylabel("KiB/s (approx)")
ax.grid(axis='y', alpha=0.25)
ax.legend(frameon=False)
plt.tight_layout()
plt.savefig('/tmp/viz_net.png', dpi=150)
PY

  wslview /tmp/viz_net.png 2>/dev/null || xdg-open /tmp/viz_net.png 2>/dev/null \
  || zenity --info --text="Saved: /tmp/viz_net.png" --width=320
}
``

chart_battery_matplotlib() {
python3 - <<'PY'
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import json, subprocess

# Query Windows WMI via PowerShell
try:
    raw = subprocess.check_output([
        'powershell.exe',
        '-NoProfile','-Command',
        '(Get-WmiObject Win32_Battery | Select EstimatedChargeRemaining,BatteryStatus | ConvertTo-Json)'
    ])
    data = json.loads(raw.decode('utf-8', errors='ignore'))
    if isinstance(data, list): data = data[0] if data else {}
except Exception:
    data = {}

pct = float(data.get('EstimatedChargeRemaining', 0))
status_code = int(data.get('BatteryStatus', 0))

status_map = {
  1:'Discharging', 2:'AC/Unknown', 3:'Full', 4:'Low',
  5:'Critical', 6:'Charging', 7:'Charging High', 8:'Charging Low',
  9:'Charging Critical', 10:'Undefined', 11:'Partially Charged'
}
status = status_map.get(status_code, 'Unknown')

# Donut gauge from 0..100
fig, ax = plt.subplots(figsize=(7.5,7.5))
ax.pie([pct, 100-pct], colors=['#76b7b2','#d3d3d3'], startangle=90,
       wedgeprops=dict(width=0.38, edgecolor='white'))
ax.text(0, 0, f"{pct:.0f}%\n{status}", ha='center', va='center',
        fontsize=22, fontweight='bold')
ax.set_title("Battery (Windows WMI via WSL)", fontsize=18, pad=16)
ax.axis('equal'); plt.tight_layout()
plt.savefig('/tmp/viz_battery.png', dpi=150)
PY
wslview /tmp/viz_battery.png 2>/dev/null || xdg-open /tmp/viz_battery.png 2>/dev/null \
|| zenity --info --text="Saved: /tmp/viz_battery.png" --width=320
}


# --- Safe size defaults (keep these near the top of your script) ---
MENU_WIDTH=${MENU_WIDTH:-800}
MENU_HEIGHT=${MENU_HEIGHT:-480}
INFO_WIDTH=${INFO_WIDTH:-900}
INFO_HEIGHT=${INFO_HEIGHT:-600}
SMALL_WIDTH=${SMALL_WIDTH:-480}
SMALL_HEIGHT=${SMALL_HEIGHT:-140}

health_check() {
python3 - <<'PY'
import os, sys, json, subprocess, time
from datetime import datetime

# Try to use psutil for reliable metrics
try:
    import psutil
except Exception:
    print("psutil not installed. Please: sudo apt install -y python3-psutil")
    sys.exit(1)

good = []
improve = []
info = []

# --- Timestamp and hostname ---
ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
host = subprocess.check_output(['hostname']).decode().strip()

# --- Disk usage (root) ---
du = psutil.disk_usage('/')
disk_pct = du.percent
if disk_pct >= 90:
    improve.append(f"Disk space on / is {disk_pct:.0f}% used — free space urgently. Tip: remove large logs/temp or move data off the disk.")
elif disk_pct >= 80:
    info.append(f"Disk space on / is {disk_pct:.0f}% used — consider cleanup soon.")
else:
    good.append(f"Disk space on / is healthy ({disk_pct:.0f}% used).")

# --- RAM usage ---
vm = psutil.virtual_memory()
ram_pct = vm.percent
if ram_pct >= 90:
    improve.append(f"RAM usage is {ram_pct:.0f}% — close heavy apps, check memory-hungry processes.")
elif ram_pct >= 80:
    info.append(f"RAM usage is {ram_pct:.0f}% — monitor; could impact performance under load.")
else:
    good.append(f"RAM usage is healthy ({ram_pct:.0f}%).")

# --- Swap usage ---
sw = psutil.swap_memory()
if sw.percent >= 50:
    improve.append(f"Swap usage is {sw.percent:.0f}% — system is swapping; performance may suffer.")
elif sw.percent > 0:
    info.append(f"Swap usage is {sw.percent:.0f}% — some swapping observed.")

# --- CPU sample (10 seconds) ---
samples = []
for _ in range(10):
    samples.append(psutil.cpu_percent(interval=1))
cpu_avg = sum(samples)/len(samples)
cpu_max = max(samples)
if cpu_avg >= 85 or cpu_max >= 95:
    improve.append(f"CPU usage high — avg {cpu_avg:.0f}% (max {cpu_max:.0f}%). Investigate busy processes.")
elif cpu_avg >= 70:
    info.append(f"CPU usage moderately high — avg {cpu_avg:.0f}% (max {cpu_max:.0f}%).")
else:
    good.append(f"CPU usage is healthy — avg {cpu_avg:.0f}% (max {cpu_max:.0f}%).")

# --- Network latency (ping 8.8.8.8, 3 probes) ---
def ping_avg():
    try:
        res = subprocess.run(
            ['bash','-lc','ping -c 3 -W 2 8.8.8.8'],
            capture_output=True, text=True, timeout=10
        )
        if res.returncode != 0:
            return None
        # Parse rtt min/avg/max from the last line: "rtt min/avg/max/mdev = 12.345/34.567/..."
        for line in res.stdout.splitlines():
            if 'min/avg/max' in line or 'rtt min/avg/max' in line:
                parts = line.split('=')[1].strip().split('/');  # min, avg, max, mdev
                return float(parts[1])
        return None
    except Exception:
        return None

lat = ping_avg()
if lat is None:
    info.append("Network latency check: ping failed (firewall/ICMP blocked?).")
else:
    if lat < 50:
        good.append(f"Network latency is good (~{lat:.0f} ms to 8.8.8.8).")
    elif lat < 150:
        info.append(f"Network latency is moderate (~{lat:.0f} ms).")
    else:
        improve.append(f"Network latency is high (~{lat:.0f} ms) — check Wi‑Fi quality, DNS, or ISP.")

# --- Battery (WSL via Windows WMI) ---
def windows_battery():
    try:
        raw = subprocess.check_output([
            'powershell.exe','-NoProfile','-Command',
            '(Get-WmiObject Win32_Battery | Select EstimatedChargeRemaining,BatteryStatus | ConvertTo-Json)'
        ], timeout=5)
        data = json.loads(raw.decode('utf-8', errors='ignore'))
        if isinstance(data, list):
            data = data[0] if data else {}
        return data
    except Exception:
        return {}

bat = windows_battery()
if bat:
    pct = float(bat.get('EstimatedChargeRemaining', 0))
    status_code = int(bat.get('BatteryStatus', 0))
    status_map = {
        1:'Discharging',2:'AC/Unknown',3:'Full',4:'Low',5:'Critical',
        6:'Charging',7:'Charging High',8:'Charging Low',9:'Charging Critical',
        10:'Undefined',11:'Partially Charged'
    }
    status = status_map.get(status_code, 'Unknown')

    if pct < 20 and status != 'Charging':
        improve.append(f"Battery is low ({pct:.0f}%) and {status}. Plug in soon.")
    elif pct < 40 and status != 'Charging':
        info.append(f"Battery is {pct:.0f}% and {status}.")
    else:
        good.append(f"Battery: {pct:.0f}% ({status}).")

# --- Build report text ---
lines = []
lines.append(f"=== System Health Report ===")
lines.append(f"Host: {host}")
lines.append(f"Time: {ts}")
lines.append("")

def section(title, items):
    lines.append(title)
    if not items:
        lines.append("  • None")
    else:
        for s in items:
            lines.append(f"  • {s}")
    lines.append("")

section("Good 👍", good)
section("Improve ⚠️", improve)
section("Info ℹ️", info)

report = "\n".join(lines)
with open('/tmp/health.txt','w',encoding='utf-8') as f:
    f.write(report)
PY

zenity --text-info --title="System Health (Good & Improve)" \
       --width="${INFO_WIDTH:-900}" --height="${INFO_HEIGHT:-600}" \
       --filename="/tmp/health.txt"

} 


# ---------- UI ----------

show_text_dialog() {
  local title="$1"; shift
  local content="$*"
  local t; t=$(tmpfile)
  printf "%s\n" "$content" > "$t"
  zenity --text-info --title="$title" --width=900 --height=600 --filename="$t" \
    --ok-label="Close"
  rm -f "$t"
}


main_menu() {
  while true; do
    local choice
    choice=$(zenity --list \
      --title="****** System Info check by Anuj *****" \
      --width=800 --height=480 \
      --column="Section" --column="Description" \
      "Live Monitor"      "Real-time CPU/RAM updates" \
      "Overview"      "OS, kernel, uptime" \
      "CPU"           "Model & cores" \
      "Memory"        "free -h and meminfo" \
      "Kernel Modules"    "Loaded modules (lsmod)" \
      "Disks"         "lsblk, df" \
      "Power"             "Battery / AC information" \
      "Network"       "ip addr (brief), route, DNS" \
      "Processes"     "Top by CPU" \
      "Services"      "Running systemd services" \
      "Devices"       "PCI & USB (if available)" \
      "GPU"           "Graphics hardware info" \
      "RAM Chart (Matplotlib)"   "Donut chart of RAM used/free" \
      "Disk Chart (Matplotlib)"  "Donut chart of / used/free" \
      "CPU Chart (30s line)"     "Line chart with avg & max markers" \
      "Network Chart (bars)"     "Top interfaces Rx/Tx over 1s" \
      "Battery Gauge (WSL)"      "Windows WMI via PowerShell" \
      "System Health (Good & Improve)" "Analyze and show recommendations" \
      "Export Report" "Save complete report to a file" \
      "Quit"          "Exit") || exit 0

    case "$choice" in
      "Live Monitor")     live_monitor ;;
      "Overview")      show_text_dialog "Overview"      "$(sec_overview)" ;;
      "CPU")           show_text_dialog "CPU"           "$(sec_cpu)" ;;
      "Memory")        show_text_dialog "Memory"        "$(sec_memory)" ;;
      "Kernel Modules")   show_text_dialog "Kernel Modules" "$(sec_modules)" ;;      
      "Disks")         show_text_dialog "Disks & Filesystems" "$(sec_disks)" ;;
      "Power")            show_text_dialog "Power / Battery" "$(sec_power)" ;;
      "Network")       show_text_dialog "Network"       "$(sec_network)" ;;
      "Processes")     show_text_dialog "Processes"     "$(sec_processes)" ;;
      "Services")      show_text_dialog "Services"      "$(sec_services)" ;;
      "Devices")       show_text_dialog "Devices"       "$(sec_devices)" ;;
      "GPU")          show_text_dialog "GPU" "$(sec_gpu)" ;; 
      "RAM Chart (Matplotlib)")    chart_ram_matplotlib ;;
      "Disk Chart (Matplotlib)")   chart_disk_matplotlib ;;
      "CPU Chart (30s line)")      chart_cpu_line_matplotlib ;;
      "Network Chart (bars)")      chart_net_bars_matplotlib ;;
      "Battery Gauge (WSL)")       chart_battery_matplotlib ;;
      "System Health (Good & Improve)") health_check ;;      
      "Export Report") export_report_dialog ;;
      "Quit")          exit 0 ;;
    esac
  done
}

# ---------- Run ----------
require zenity awk sed df ip ps
main_menu
