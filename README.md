
# System Info (WSL Zenity Tool)

A lightweight **WSL-friendly** system info & health-check utility with a **Zenity GUI**. It provides:
- **Text-based system info** (CPU, memory, disks, services, devices)
- **Matplotlib charts** (RAM/ disk donuts, CPU 30s line, network throughput bars)
- **Battery** (via Windows WMI in WSL)
- **Health Check** that highlights **Good** vs **Improve** items with actionable tips
- Optional **Plotly HTML dashboard** (interactive, opens in your Windows browser via `wslview`)

## Why this project?

- **WSL-safe GUI**: Uses **Zenity** for dialogs—compact, portable, and no heavy desktop dependencies.  
- **Headless plotting**: Matplotlib **Agg** backend saves charts as PNG (no X server needed).  
- **Cross-boundary battery data**: Reads battery info from **Windows WMI** via `powershell.exe` inside WSL.  
- **Modern visualization**: Plotly HTML dashboard for interactive charts, opened via `wslview`.

> Notes / references  
> • Zenity text-info docs: GNOME Help (Text Information Dialogue) [1](https://packages.ubuntu.com/jammy/python3-psutil)  
> • Matplotlib “Agg” backend (headless saves): Matplotlib backends docs [2](https://www.installati.one/install-python3-plotly-ubuntu-22-04/)  
> • PEP 668 (externally-managed environment; pip on Ubuntu 23.04+): guidance & workarounds [3](https://exchangetuts.com/generation-of-pie-chart-using-gnuplot-1640300523997264)[4](http://gnuplot.info/docs/loc5012.html)

---

## Features

- **System Info**: Overview, CPU, Memory, Disks, Network, Processes, Services, Devices, GPU
- **Charts**:
  - RAM donut (Used vs Free)
  - Disk donut (root `/`)
  - CPU 30s line (average + max marker)
  - Network bars (top NICs; Rx/Tx over 1s)
- **Battery Gauge (WSL)**: WMI via `powershell.exe`
- **Health Check**:
  - Disk, RAM, CPU (avg & spikes), Swap, Network latency, Battery
  - Categorized into **Good**, **Improve**, **Info** with tips
- **Interactive Dashboard (Plotly)**:
  - RAM & Disk donuts, CPU line, Network bars in one HTML page
  - Opens in Windows browser via `wslview` or Linux via `xdg-open`

---

## Setup (WSL)

1. **Clone** the repo:
   ```bash
   git clone https://github.com/<your-username>/sysinfo-zenity.git
   cd sysinfo-zenity
