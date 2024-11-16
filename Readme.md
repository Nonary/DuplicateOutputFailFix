## Overview

If you're using **Sunshine** to stream from a laptop that has both an integrated GPU (iGPU) and a dedicated GPU (dGPU), you might encounter issues where streaming breaks or performance drops. This happens because the system switches between the two GPUs to balance performance and battery life, but Sunshine doesn't handle these switches well due to limitations with **DXGI** (DirectX Graphics Infrastructure).

This guide will help you set up your laptop so that Sunshine always uses the correct GPU for streaming, ensuring smooth performance and preventing common issues like black screens or error messages.

---

## The Problem

### How Hybrid GPUs Work

- **Integrated GPU (iGPU):** Built into your laptop's processor (like Intel HD Graphics), it's energy-efficient and handles everyday tasks.
- **Dedicated GPU (dGPU):** A separate graphics card (like NVIDIA or AMD), it's more powerful and handles demanding tasks like gaming or streaming.

Your laptop switches between the iGPU and dGPU to save energy or boost performance as needed.

### Issues with Sunshine and DXGI

Sunshine uses DXGI to capture your screen, but DXGI has limitations:

- **GPU Mismatch:** If Sunshine is trying to capture from one GPU but encode using another, it can cause:
  - **Black Screens:** No video output in your stream.
  - **Error Messages:** Such as `Duplicate Output Failed`.

- **Immutable GPU Preference:** Once Sunshine starts, it can't change which GPU it's using without restarting. Since laptops switch GPUs dynamically, Sunshine gets stuck using the wrong one.

Suppose you have a laptop with an iGPU and decide to use a dummy plug or virtual display device configured to be always attached to the dGPU. This will cause problems because Sunshine will often pick the integrated graphics card, as the OS is designed to use the most efficient GPU by default (since it is a laptop).

**Impact:**
1. Constant errors in Sunshine logs of it trying to probe a display repeatedly.
2. On the off chance the stream does start, it will display a black screen with no video output.

You may notice this issue occur more frequently after installing the Virtual Display Driver that forces itself on the dGPU. In the previous version, it would always pick the iGPU (much like Sunshine does right now) due to the reasons mentioned earlier.

---

## The Workaround Solution

To fix these issues, we'll do the following:

1. **Install a Fixed Version of Sunshine:** This version contains fixes to make Sunshine less likely to pick the iGPU.
2. **Set Up a Virtual Display Driver:** This forces your laptop to always have a display connected directly to the dGPU.
3. **Use MonitorSwapper Script:** This will temporarily disable the built-in display, which is attached to the iGPU, to swap over to the virtual display forced to be on the dGPU. Please make sure to use the one suggested in this guide, as it has extra code to ensure that the display does not revert while Sunshine is rebooting. If you have your own monitor swap script, it would likely swap displays again during the restart of Sunshine, which would break the script since your internal display is almost always attached to the iGPU.
4. **Install this Script:** This script will monitor Sunshine every time you make a connection and, when it detects that the GPU preference needs to be changed, it will automate rebooting Sunshine on your behalf.

**Important to Note:** The script **MUST** reboot Sunshine to work around the problem. This means every time this needs to be done, you will connect to your computer using Moonlight and get immediately kicked out back to the "Select a Host" screen. This is normal, meaning if you fail on the first connection attempt, you need to try again, and it should work without needing to restart Sunshine, unless it needs to swap displays again.

### Prerequisites

- **Sunshine** installed on your Windows laptop.
- Administrator rights on your laptop.
- Basic ability to install software and run scripts.

---

## Step-by-Step Guide

### **Step 1: Install the Fixed Version of Sunshine**

The standard version of Sunshine might choose the iGPU by mistake. A pre-release version fixes this.

**What to Do:**

1. **Download the Pre-release Version:**
   - Go to the [Sunshine Pre-release Downloads](https://github.com/LizardByte/Sunshine/tags).
   - Download a version starting with `v2024` (e.g., `v2024.0`).

**Note:** Upgrading to this version adds new features that might make downgrading difficult later.

---

### **Step 2: Install a Virtual Display Driver**

This driver creates a fake display that keeps the dGPU active, preventing the system from switching back to the iGPU.

**What to Do:**

1. **Download the Driver:**
   - Visit the [Virtual Display Driver Releases](https://github.com/itsmikethetech/Virtual-Display-Driver/releases/tag/24.9.11).
   - Download the special version named `IDDSampleDriver`.

2. **Install the Driver:**
   - Follow the instructions provided on the download page.
   - After installation, check your display settings to ensure the virtual display is recognized.

3. **Adjust Sunshine Settings: (VERY IMPORTANT!)**
   - Open Sunshine's Web UI.
   - Go to `Configuration > Audio/Video`.
   - Make sure **Output Name** and **Adapter Name** are both **blank**.

---

### **Step 3: Set Up Monitor Swap Automation (IMPORTANT!)**

This script will automate temporarily disabling the internal display to force the virtual display, which is guaranteed to be on the dGPU. 

The reason you need to use this specific script to handle the display swaps is that it has been modified to allow Sunshine to restart without immediately reverting back to your original display. This is important because Sunshine needs to reboot with the other display active to properly pick the dGPU.

**What to Do:**

1. **Download the Automation Script:**
   - Go to the [Monitor Swap Automation Releases](https://github.com/Nonary/MonitorSwapAutomation/releases/latest).
   - Download the latest version.

2. **Install and Configure:**
   - Follow the installation instructions provided.
   - Configure the script to switch to the virtual display when necessary.

3. (Important) **Configure primary profile for extended mode**:
   - In order to force a hybrid GPU system into using the dedicated GPU on the desktop you need to set up your primary.cfg file to leave both monitors active.
   - Do not "zero out" the dummy display on primary.cfg, instead make sure it has values configured for it.
   - This will force the desktop to always be attached to GPU going forward.

---

### **Step 4: Install this Script**

This script monitors Sunshine and restarts it if it starts using the wrong GPU.

**What to Do:**

1. **Download the Script:**
   - Visit the [Releases](https://github.com/Nonary/DuplicateOutputFailFix/releases/latest).
   - Download the latest version.

2. **Configure the Script:**
   - If Sunshine isn't installed in the default location, edit the `settings.json` file to point to the correct path.

3. **Install the Script:**
   - Run `install.bat` (double-click it).
   - Allow any administrative permissions it requests.

---

## How This Solution Works

- **Virtual Display Driver:** Keeps the dGPU active by simulating a display connected to it.
- **Monitor Swap Automation:** Ensures your laptop uses the dGPU for the main display.
- **This Script:** Automates rebooting Sunshine with the correct display to ensure it picks the dGPU when needed.

---

## Important Notes

- **Stream Interruptions:** By design, this script reboots Sunshine when necessary. This means you will experience the first connection attempt immediately kicking you out.
- **Startup Delays:** The startup delay for a stream will be significantly impacted if you haven't installed the monitor swap before; it will be about 5-8 seconds slower.
- **Future Updates:** Upcoming features in Sunshine, such as the built-in monitor swap, will not work with this workaround. You must continue to use the monitor swap script.
- **Configuration Reminder:** Ensure that **Output Name** and **Adapter Name** in Sunshine's settings are blank.

---

## Troubleshooting

- **Stream Isn't Starting:**
  - Verify the virtual display driver is installed correctly.
  - Check that the monitor swap automation is working.

- **Script Isn't Restarting Sunshine:**
  - Ensure the script has administrative permissions.
  - Look at the script's log files for errors (usually in the same folder as the script).

- **Still Seeing Errors or iGPU is Used:**
  - Double-check all steps, especially ensuring Sunshine's settings are correct.
  - Ensure the monitor swap automation is properly set up.

---

## Additional Information

### Why This Issue Happens

Sunshine uses DXGI for screen capture, which can't handle situations where the display and the encoding GPU are different. Since laptops with hybrid GPUs switch between the iGPU and dGPU, Sunshine can end up using the wrong GPU, causing errors.

### Future Solutions

Ideally, Sunshine would need to be redesigned to handle GPU preferences dynamically, possibly by separating the capturing and encoding into different processes. However, this would be a very challenging task because the code for Sunshine is not very modular and would require low-level programming features such as shared memory. It is unlikely to be fixed in the next year or two. This script is a workaround to get it to work for now while Sunshine eventually fixes the issue on its own.