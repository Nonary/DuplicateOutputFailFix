## Overview

Laptops with hybrid GPU setups dynamically switch between the integrated GPU (iGPU) and the dedicated GPU (dGPU) to balance performance and energy consumption. While this setup works well for most applications, streaming software like **Sunshine** can encounter issues if the GPUs used for display and streaming tasks don’t align.

This guide addresses these complications and provides a comprehensive, step-by-step solution to ensure that **Sunshine** consistently uses the correct GPU for streaming, preventing common issues such as streaming breaks and performance degradation.

## The Problem

### Hybrid GPU Dynamics

Modern laptops often feature both an integrated GPU (iGPU) and a dedicated GPU (dGPU). The operating system (OS) optimizes energy usage by dynamically assigning tasks between these GPUs based on current demands. While this approach enhances efficiency, it introduces complexities for certain applications, particularly streaming software like **Sunshine**.

### Specific Issues with Sunshine

**Sunshine** relies on **DXGI** (DirectX Graphics Infrastructure) for capturing video. However, **DXGI** imposes restrictions when dealing with hybrid GPU setups:

- **GPU Mismatch**: If your monitor is connected to a different GPU than the one **Sunshine** uses for streaming, you may experience:
  - **No Video Received**: Streams may fail to capture any video output.
  - **`Duplicate Output Failed` Errors**: Errors indicating that the output duplication for streaming has failed.

- **Windows API Limitations**: Windows allows setting GPU preferences for individual processes, but this preference is immutable for the lifetime of the process. Since **Sunshine** is designed to run continuously:
  - **GPU Switching**: After a few streams, the GPU may switch again, causing **Sunshine** to break until the service is restarted.
  
- **Complex Display Configurations**: In scenarios where the laptop display is managed by the iGPU and an external monitor (or dummy plug) is handled by the dGPU:
  - **Display Configuration Challenges**: You must switch the display to the dGPU and restart **Sunshine** to apply the correct GPU preference.
  - **Profile Reversion Risks**: Ensuring that the display profile doesn’t revert before **Sunshine** restarts is critical to maintaining streaming stability.

### Root Cause Analysis

Approximately a year or two ago, efforts were made to mitigate these issues by introducing a **DXGI probe utility**. The core problem lies in how **DXGI** handles screen capturing:

- **Single GPU Binding**: **DXGI** won’t allow screen capture if the display is connected to a different GPU than the one performing the encoding. This is problematic for setups with, for example, an Intel iGPU and an NVIDIA dGPU, where the system may default to using Intel’s QuickSync (iGPU) instead of the NVIDIA encoder (dGPU).

- **Process Lifetime Constraint**: Once a GPU preference is set for a process like **Sunshine**, it cannot be changed without restarting the process. Given that **Sunshine** is intended to run continuously, any dynamic GPU switching by the OS can lead to streaming failures.

## Solution

To address these challenges, a combination of software patches, virtual display drivers, and automation scripts is required. This comprehensive approach ensures that **Sunshine** consistently utilizes the dGPU for streaming, thereby maintaining performance and preventing interruptions.

### Prerequisites

- **Sunshine Streaming Software** installed and configured.
- Administrative access to your Windows laptop.
- Basic understanding of installing and running scripts.

### Step 1: Install Patched Sunshine Executable

The GPU preference prober in the 0.23.0 release of **Sunshine** may incorrectly select the iGPU instead of the dGPU. This issue has been addressed in [PR 3002](https://github.com/LizardByte/Sunshine/pull/3002) and is included in the pre-release versions of **Sunshine**. The official fix will be available in version 0.24, but until then, you need to install the pre-release version.

**Important:** Once you upgrade to the pre-release version, downgrading is not straightforward due to the introduction of new features.

**Action:**

- **Download Pre-release Sunshine:**
  - Visit the [Sunshine Pre-release Tags](https://github.com/LizardByte/Sunshine/tags) page.
  - Download any tag starting with `v2024`, as these contain the necessary GPU preference fix.

### Step 2: Configure Virtual Display Driver

A virtual display ensures that the dGPU remains the primary GPU for streaming tasks, preventing the OS from switching to the iGPU.

1. **Download the Virtual Display Driver:**
   - Visit the [Virtual Display Driver Releases](https://github.com/itsmikethetech/Virtual-Display-Driver/releases/tag/24.9.11).
   - Download the special version of `IDDSampleDriver` configured to always attach to the dGPU.

2. **Install the Driver:**
   - Follow the installation instructions provided in the repository.
   - Ensure the virtual display is correctly set up and recognized by your system.

3. **Remove Adapter and Monitor Configuration from Sunshine:**
   - Open the Sunshine Web UI and navigate to `Configuration > Audio/Video`.
   - Ensure that both the **Output Name** and **Adapter Name** fields are left blank. If these fields are populated, the automation script will not function correctly.

### Step 3: Set Up Monitor Swap Automation

Automating the monitor swap ensures that your display remains consistently connected to the dGPU, preventing the OS from reverting to the iGPU.

1. **Download Monitor Swap Automation:**
   - Visit the [Monitor Swap Automation Releases](https://github.com/Nonary/MonitorSwapAutomation/releases/latest) page.
   - Download the latest release.

2. **Install and Configure:**
   - Follow the installation guide provided in the repository.
   - Configure the automation tool to swap the display to the virtual display as needed, ensuring the dGPU remains active for streaming.

### Step 4: Install GPU Preference Script

This script monitors **Sunshine** and restarts it if the GPU preference changes, maintaining a stable streaming environment.

1. **Download the Script from Releases:**
   - Visit the [GPU Preference Script Releases](https://github.com/Nonary/DuplicateOutputFailFix/releases/latest) page.
   - Download the latest release.

2. **Configure the Script:**
   - If **Sunshine** is installed in a non-default directory, update the `settings.json` file accordingly before installation.
   
3. **Install the Script:**
   - Run `install.bat` by double-clicking it to install the script. Ensure you have administrative privileges during installation.

## How It Works

1. **Hybrid GPU Monitoring:**
   - The GPU preference script continuously monitors the GPU preferences assigned to **Sunshine**.

2. **Detect GPU Changes:**
   - If the laptop's GPU switches from the dGPU to the iGPU (or vice versa), the script detects this change.

3. **Restart Sunshine:**
   - Upon detecting a GPU preference change, the script automatically restarts **Sunshine**.
   - This action re-applies the correct GPU preference, ensuring **Sunshine** consistently uses the dGPU for streaming.

4. **Seamless Streaming:**
   - The combination of the virtual display driver and monitor swap automation ensures that the dGPU remains the primary GPU for streaming tasks.
   - This setup minimizes disruptions, preventing issues like black screens and `Duplicate Output Failed` errors.

## Important Notes

- **Stream Interruption:**
  - Restarting **Sunshine** will cause your current stream to end momentarily. This is necessary to re-establish the correct GPU preference.

- **Delay in Stream Start:**
  - There may be a slight delay when starting a new stream as the script ensures the correct GPU is in use.

- **Compatibility Considerations:**
  - The upcoming built-in monitor profile restoration feature in **Sunshine** may conflict with this script, as it could revert display profiles that the script relies on.

- **Ensure Proper Configuration:**
  - Double-check that both the **Output Name** and **Adapter Name** fields in the Sunshine Web UI are left blank to allow the script to function correctly.

## Troubleshooting

- **Stream Not Starting:**
  - Verify that the virtual display driver is correctly installed.
  - Ensure that the monitor swap automation is functioning as expected.

- **Script Not Restarting Sunshine:**
  - Confirm that the script has the necessary administrative permissions.
  - Check the script’s log directory for detailed error messages or issues.

- **Duplicate Output Errors Persist** or **iGPU is Still Selected:**
  - Revisit all steps in this guide to ensure none were missed, particularly the removal of monitor configurations in Sunshine.
  - Ensure that the [Monitor Swap Automation Script](https://github.com/Nonary/MonitorSwapAutomation/releases/latest) is correctly set up, guaranteeing that your laptop maintains a display connected directly to the dGPU.

## Additional Insights

### Background on the Issue

Efforts to resolve these GPU switching issues initially focused on adding a **DXGI probe utility** to **Sunshine**. However, due to the inherent limitations of **DXGI** and the complexities of hybrid GPU management, a more robust solution involving external scripts and drivers was necessary.

### Future Developments

The ideal fix would involve significant modifications to **Sunshine’s** architecture, such as running each streaming session in its own process. This approach would allow dynamic setting of GPU preferences as the laptop switches between iGPU and dGPU. However, this requires advanced development expertise and is beyond the current scope.

In the meantime, the provided workaround offers a practical solution for laptop users, ensuring reliable streaming performance by enforcing the use of the dedicated GPU.

