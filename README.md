# NetHunter Kernel for Sony SM6375 Devices (Xperia 10 V, 10 IV, etc.)

This repository contains a standalone build script and kernel sources optimized for Kali NetHunter on LineageOS (SM6375).

## 1. Quick Build (Default: pdx235)

To build the NetHunter kernel for the Xperia 10 V (pdx235), simply run:
```bash
./build.sh
```
This will compile the kernel using the pre-configured `nethunter_pdx235_defconfig` and output the compiled `Image` in `build/arch/arm64/boot/Image`.

## 2. Building for Other SM6375 Devices (pdx225, pdx235_j)

If you need to build for another device variant, you must first generate its NetHunter defconfig.

### Step 2.1: Generate the base config
Run the following command, replacing `<DEVICE>` with your device codename (e.g., `pdx225` or `pdx235_j`):
```bash
make O=out ARCH=arm64 gki_defconfig vendor/holi-qgki_defconfig diffconfig/common.config diffconfig/<DEVICE>.config
mv out/.config arch/arm64/configs/nethunter_<DEVICE>_defconfig
```

### Step 2.2: Compile
Run the build script specifying your device:
```bash
./build.sh nethunter <DEVICE>
```
*Example:* `./build.sh nethunter pdx225`

> **Dependencies:** For build environment requirements, refer to the [LineageOS Build Guide](https://wiki.lineageos.org/devices/pdx235/build/).

---

## 3. Packaging the NetHunter Kernel Installer ZIP

Once your kernel is built, you can package it into a flashable ZIP using the official NetHunter tools.

### Step 3.1: Download Installer Tools
```bash
git clone https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-installer.git
cd kali-nethunter-installer/

git clone --depth 1 --branch main --filter=blob:limit=2m --no-checkout https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernels.git kernels
cd kali-nethunter-kernels
git sparse-checkout set bin example_scripts patches sixteen/oneplus7-los-23.2
cd ..
```

### Step 3.2: Inject the Kernel
Place your compiled `Image` into the appropriate device folder. (Replace `pdx235` with your device if necessary):
```bash
mkdir -p kernels/sixteen/pdx235-los
cp ../android_kernel_sony_sm6375/build/arch/arm64/boot/Image kernels/sixteen/pdx235-los/
```
*(Note: Do not include the `modules` folder. The kernel is patched with a "vermagic bypass" and will automatically load the stock LineageOS modules).*

### Step 3.3: Generate the ZIP
```bash
python3 build.py -k pdx235-los --sixteen -fs full
```
Your flashable `kernel-nethunter-*.zip` will be generated in the root directory!

---

## 4. Installation Instructions

1. **Install LineageOS**: Follow the official [LineageOS Installation Wiki for pdx235](https://wiki.lineageos.org/devices/pdx235/install/).
   - *Optional but recommended:* At Step 4 of the wiki, when flashing `vbmeta`, it is good practice to disable AVB verification to prevent bootloops with custom kernels:
     `fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img`
2. **Install Magisk**: At Step 8 of the LineageOS wiki (sideloading add-ons), sideload the [Magisk APK](https://github.com/topjohnwu/Magisk/releases/).
3. **Download or Build NetHunter Kernel**: 
   - Compile it yourself using the steps above, OR
   - Download the pre-compiled release from [Tom60chat's Releases](https://github.com/Tom60chat/android_kernel_sony_sm6375/releases).
4. **Initial Setup**: Boot your phone and complete the Android setup wizard (OOBE).
5. **Configure Magisk**: Open the Magisk app. It will ask to do an additional setup and reboot. Let it do so. (Two time)
6. **Flash the Kernel**: Once rebooted, open Magisk again, go to the **Modules** tab, and flash your `kernel-nethunter-*.zip`.
7. **Reboot & Enjoy**: Reboot your device. You should be greeted by the Kali NetHunter boot animation!

---

## 5. Important Notes & Known Issues

### ⚠️ OTA Updates & Recovery
On modern A/B devices like the Xperia 10 V, the recovery is integrated directly into the `boot.img` partition.
- **Flashing this custom kernel will overwrite your recovery partition.**
- As a result, **OTA (Over-The-Air) updates will not be possible** while the NetHunter kernel is installed.
- **To restore OTA functionality or recovery:** You must re-flash the original LineageOS `boot.img` via fastboot, which will, in turn, remove the NetHunter kernel. You can also use `fastboot boot boot.img` to temporarily boot the LineageOS recovery without installing it.