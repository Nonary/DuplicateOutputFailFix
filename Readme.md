## Table of Contents

- [Overview](#overview)
- [What This Script Does](#what-this-script-does)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Step 1: Install Latest Pre-release of Sunshine](#step-1-install-latest-pre-release-of-sunshine)
  - [Step 2: Configure Virtual Display Driver](#step-2-configure-virtual-display-driver)
  - [Step 3: Set Up Monitor Swap Automation](#step-3-set-up-monitor-swap-automation)
  - [Step 4: Install GPU Preference Script](#step-4-install-gpu-preference-script)
- [How It Works](#how-it-works)
- [Usage](#usage)
- [Important Notes](#important-notes)
- [Troubleshooting](#troubleshooting)


## Overview

Laptops with hybrid GPU setups dynamically switch between the integrated GPU (iGPU) and the dedicated GPU (dGPU) to balance performance and energy consumption. Sunshine, a streaming application, relies on a Windows API capturing method called DXGI, which has limitations when capturing displays across different GPUs. Specifically, if Sunshine runs on the dGPU while the display is on the iGPU, it will be unable to stream. 

This issue is particularly problematic for gaming laptops. Fixing it would require a significant rewrite of Sunshine's code because the Windows API only allows setting a GPU preference once during the lifetime of a process. Since Sunshine is designed to run continuously, this limitation presents a major obstacle.

To address this, the provided script detects when the GPU preference needs to be reset. It automates the process of restarting Sunshine, allowing it to set the GPU preference again, thereby working around the "once per lifetime" limitation.


## What This Script Does

- **Monitors GPU Preferences:** Continuously checks which GPU **Sunshine** is using.
- **Automates GPU Switching:** Detects when the GPU preference changes and automatically restarts **Sunshine** to enforce the correct GPU usage.
- **Maintains Dedicated GPU Usage:** Ensures the dGPU remains the primary GPU for streaming by managing virtual displays and monitor connections.

## Prerequisites

- **Sunshine Streaming Software:** Installed and configured.
- **Administrative Access:** Required on your Windows laptop.
- **Basic Scripting Knowledge:** Understanding of installing and running scripts.

## Installation

Follow these steps to set up the GPU Fix Script for **Sunshine**.

### Step 1: Install Latest Pre-release of Sunshine

The GPU preference prober in the 0.23.0 release of **Sunshine** may select the wrong GPU. This issue has been fixed in [PR 3002](https://github.com/LizardByte/Sunshine/pull/3002) and has been approved and merged into the pre-release of **Sunshine**. It will be officially added in version 0.24, but for now, you will need to install the pre-release version. Please note that once upgraded to pre-release, it cannot be easily downgraded as there are new features that do not exist in older versions.

**Action:**

- **Download Pre-release Sunshine:** Visit [Sunshine Pre-release Tags](https://github.com/LizardByte/Sunshine/tags) and download any tag starting with v2024, as it contains the required fix.

### Step 2: Configure Virtual Display Driver

A virtual display ensures the dGPU is consistently used for streaming.

**Action:**

1. **Download Virtual Display Driver:**
   - Visit the [Virtual Display Driver Releases](https://github.com/itsmikethetech/Virtual-Display-Driver/releases/tag/24.9.11).

2. **Install the Driver:**
   - Follow the installation instructions provided in the [repository](https://github.com/itsmikethetech/Virtual-Display-Driver).
   - Verify that the virtual display is correctly set up and recognized by your system.
   - The `.xml` file included in the download is optional and does not need to be moved to `C:\IddSampleDriver`.

### Step 3: Set Up Monitor Swap Automation

Automating the monitor swap keeps your display connected to the dGPU.

**Action:**

1. **Download Monitor Swap Automation:**
   - Visit the [Monitor Swap Automation Releases](https://github.com/Nonary/MonitorSwapAutomation/releases/latest) and download the latest version.

2. **Install and Configure:**
   - Follow the installation guide in the [repository](https://github.com/Nonary/MonitorSwapAutomation).
   - Configure it to swap to the virtual display as needed.

### Step 4: Install GPU Preference Script

This script monitors **Sunshine** logs and, if it detects the stream is going to fail due to issues with hybrid GPU switching, it will restart **Sunshine**, allowing it to reconfigure its GPU preference.

**Action:**

1. **Download the Script:**
   - [Download GPU Preference Script](https://github.com/Nonary/DuplicateOutputFailFix/releases/latest)

2. **Configure the Script:**
   - If **Sunshine** is installed in a different directory, update the `settings.json` file accordingly before installation.

3. **Install the Script:**
   - Double-click `install.bat` to install the script.

## How It Works

1. **Hybrid GPU Monitoring:**
   - The script continuously monitors the GPU preferences used by **Sunshine**, running a background process optimized for minimal memory and CPU usage.
   - If concerned about security, you can review the script code in ChatGPT to verify it is not malicious.

2. **Detect GPU Changes:**
   - If the laptop’s GPU switches (e.g., from dGPU to iGPU), the script detects this change and compares it to your active displays.
   - If the preferred GPU for your display differs from the one set in **Sunshine**, it will restart the Sunshine service, allowing it to reconfigure its GPU preference.

3. **Restart Sunshine:**
   - When the script detects a GPU priority change, either through errors in **Sunshine** logs or a change in settings, it restarts **Sunshine**.

4. **Sunshine Reconfigures GPU Preference:**
   - Once **Sunshine** restarts, it will select the correct GPU, enabling you to continue streaming without needing a manual reboot.

## Usage

1. **Start Streaming:**
   - Begin your stream as usual. The script will manage GPU preferences automatically.

## Important Notes

- This is a workaround script, meaning it doesn't fix the core issue in **Sunshine** but instead minimizes the impact of the bug causing the problem.
  
- **Stream Kickbacks (on First Attempt):** The script restarts **Sunshine** when it detects a GPU preference issue, which may cause the stream to disconnect on the first attempt. This is intentional, and there is no workaround for it.

- **Delay in Stream Start:** There may be a slight delay when starting a new stream as the script ensures the correct GPU is in use.

## Troubleshooting

- **Stream Not Starting:**
  - Ensure the virtual display driver is correctly installed.
  - Verify the monitor swap automation script is running without issues.

- **Script Not Restarting Sunshine:**
  - Check the log directory for details on potential issues.
