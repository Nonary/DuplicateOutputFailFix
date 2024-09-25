## Overview

Laptops with hybrid GPU setups dynamically switch between the integrated GPU (iGPU) and the dedicated GPU (dGPU) to balance performance and energy consumption. While this works well for most applications, streaming software like Sunshine can encounter issues if the GPUs used for display and streaming tasks don’t match.

This guide addresses these complications and provides a step-by-step solution to ensure that Sunshine consistently uses the correct GPU for streaming.

## The Problem

Windows optimizes energy usage by dynamically assigning tasks between the iGPU and dGPU. While this generally works well, issues arise with **DXGI**—a part of the Windows API used for capturing video. Specifically:

- **GPU Mismatch:** If your monitor is connected to a different GPU than the one Sunshine uses, streaming can fail. You might encounter:
  - No video received.
  - `Duplicate Output Failed` errors in Sunshine.

- **Windows Limitation:** Windows allows setting GPU preferences for processes, but this can only be done once per process lifetime. Since Sunshine is designed to run continuously:
  - After a few streams, the GPU might switch again.
  - Sunshine may break until the service is restarted.

- **Complex Scenarios:** If your laptop display is on the iGPU and an external monitor (or dummy plug) is on the dGPU:
  - You need to switch the display to the dGPU.
  - Restart Sunshine to apply the GPU preference.
  - Ensure the display profile doesn’t revert before restarting Sunshine.

## Solution

To address these issues, a script has been developed to monitor Sunshine’s GPU preferences and automatically restart the service when necessary. Additionally, setting up a virtual display ensures that the dGPU remains the primary GPU for streaming.

### Prerequisites

- **Sunshine Streaming Software** installed and configured.
- Administrative access to your Windows laptop.
- Basic understanding of installing and running scripts.

### Step 1: Configure Virtual Display Driver

A virtual display ensures that the dedicated GPU is consistently used for streaming.

1. **Download the Virtual Display Driver:**
   - Visit the [Virtual Display Driver Releases](https://github.com/itsmikethetech/Virtual-Display-Driver/releases/tag/24.9.11).
   - Download the special version of `IDDSampleDriver` configured to always attach to the dedicated GPU.

2. **Install the Driver:**
   - Follow the installation instructions provided in the repository.
   - Ensure the virtual display is set up correctly and recognized by your system.

### Step 2: Set Up Monitor Swap Automation

Automating the monitor swap ensures that your display remains connected to the dedicated GPU.

1. **Download Monitor Swap Automation:**
   - Visit the [Monitor Swap Automation Releases](https://github.com/Nonary/MonitorSwapAutomation/releases/latest) and download it.

2. **Install and Configure:**
   - Follow the installation guide in the repository.
   - Configure it to swap to the virtual display as needed.

### Step 3: Install GPU Preference Script

This script monitors Sunshine and restarts it if the GPU preference changes, maintaining a stable streaming environment.

1. **Download the Script from Releases:**
   - https://github.com/Nonary/DuplicateOutputFailFix/releases/latest

2. **Configure the Script:**
   - If Sunshine is installed on different directory, make sure to fix it in the settings.json file first before installing.
   - Install the script by double clicking on install.bat


## How It Works

1. **Hybrid GPU Monitoring:**
   - The script continuously monitors the GPU preferences used by Sunshine.

2. **Detect GPU Changes:**
   - If the laptop’s GPU switches (e.g., from dGPU to iGPU), the script detects this change.

3. **Restart Sunshine:**
   - Upon detecting a GPU preference change, the script automatically restarts Sunshine.
   - This re-applies the correct GPU preference, ensuring consistent streaming performance.

4. **Seamless Streaming:**
   - The virtual display driver and monitor swap automation maintain the dGPU as the primary GPU for streaming.
   - Minimizes disruptions and resolves issues like black screens and duplicate output errors.

## Important Notes

- **Stream Interruption:** Restarting Sunshine will cause your current stream to end momentarily. This is a necessary step to fix GPU-related issues.
- **Delay in Stream Start:** There might be a slight delay when starting a new stream as the script ensures the correct GPU is in use.
- **Compatibility:** The upcoming built-in monitor profile restoration feature in Sunshine may not work with this script, as it could revert display profiles that the script relies on.

## Troubleshooting

- **Stream Not Starting:**
  - Ensure the virtual display driver is correctly installed.
  - Verify that the monitor swap automation is functioning.

- **Script Not Restarting Sunshine:**
  - Check if the script has the necessary permissions.
  - Check log directory of the script for more details on potential issues.

- **Duplicate Output Errors Persist:**
  - Restart your laptop to reset GPU preferences.
  - Verify that both the display and Sunshine are using the dedicated GPU.

