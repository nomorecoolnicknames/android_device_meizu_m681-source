# Meizu M3 Note (M681)

**LineageOS 16.0 · Android 9 · ARM64**

Device configuration and compatibility code maintained by [ReMeizu](https://github.com/nomorecoolnicknames/remeizu).

| Target | Configuration |
| --- | --- |
| Product | `lineage_m681-userdebug` |
| Device path | `device/meizu/m681` |
| Platform | MT6755 / Helio P10 |
| Display | 1080 × 1920 |
| Kernel route | 3.18 prebuilt; optional m6-graft source route |

## Status

Earlier LOS16 hardware tests used a **4.4 kernel**: boot, display/touch, Wi-Fi, SIM1/LTE and sensors worked; camera, microphone/call audio and suspend remained incomplete. This branch selects a **3.18 prebuilt route**, so those results do not validate its current kernel configuration.

**Source available** means the listed implementation or configuration is in this repository. **External** means it also needs the matching platform, kernel or vendor inputs. **Untested** means there is no functional test for this branch.

## Components

| Subsystem | Implementation / source | Availability | Working status |
| --- | --- | --- | --- |
| Boot / storage | [BoardConfig.mk](BoardConfig.mk) · [rootdir/fstab.mt6755](rootdir/fstab.mt6755) | Config; kernel image external | Current kernel route untested |
| Display / touch | [overlay](overlay) · [device.mk](device.mk) · external MTK HWC/Mali stack | Config; kernel drivers external | Untested with this kernel/ROM configuration |
| Wi-Fi | [wifi](wifi) · [nvram](nvram) | Configuration/NVRAM repair source; HAL/firmware external | Untested |
| Bluetooth | [device.mk](device.mk) · stock MTK transport | Config; controller firmware/vendor transport external | Untested |
| SIM / LTE / calls | [rild-mtk-hidl.rc](rild-mtk-hidl.rc) | RIL service configuration; modem and MTK vendor ABI external | Untested; board-specific modem inputs required |
| Camera | [device.mk](device.mk) | Provider configuration; camera HAL and calibration external | Untested; calibration and vendor ABI remain board-specific |
| Audio | [device.mk](device.mk) · [media](media) | MTK audio service/configuration; primary HAL external | Untested on this branch |
| Sensors | [rootdir/init.m681_sensors.rc](rootdir/init.m681_sensors.rc) | Init/HAL configuration; board sensor drivers external | Untested |
| Fingerprint | [device.mk](device.mk) | Service/TEE configuration; fingerprint HAL external | Untested |
| GPS | [gps/gps.conf](gps/gps.conf) | Configuration/vendor inputs; GNSS stack external | Location fix unverified |
| Power / USB / SELinux | [BoardConfig.mk](BoardConfig.mk) · [sepolicy](sepolicy) | Kernel/HAL configuration and policy | Functional testing and enforcing policy pending |

## Build

Use a matching LineageOS 16.0 source tree and place this checkout at `device/meizu/m681`. LOS16 uses JDK 8. Provide these inputs before running lunch:

| Input | Location / requirement |
| --- | --- |
| Common device tree | `device/meizu/mt6755-common` |
| MTK RIL/HAL integration | Matching `vendor/mediatek` sources, including MTK telephony headers |
| Vendor inputs | Prepared `vendor/meizu/m681` tree matching this device and branch |
| Kernel source / headers | `kernel/meizu/meizu_m6/kernel-3.18` |
| Kernel image | `device/meizu/m681/prebuilt-kernel/Image.gz-dtb`; use the matching board kernel and DTB |

```sh
source build/envsetup.sh
lunch lineage_m681-userdebug
m -j4 bacon
```

The normal Android route uses the prebuilt. The separate `M681_SFOS_BUILD=1` route requires `M681_KERNEL_SOURCE_OVERRIDE` or `M681_M6GRAFT_KERNEL_SOURCE` pointing to the M681 m6-graft 3.18.140 source, and defaults to `m681_sfos_defconfig`.

## Next steps

- Validate the selected kernel/ROM combination without borrowing results from the earlier 4.4 build.
- Close camera, microphone/call-audio, USB transfer and suspend regressions on that combination.

The [ReMeizu overview](https://github.com/nomorecoolnicknames/remeizu/blob/main/PROJECT_STATUS.md) tracks the broader project; the [source index](https://github.com/nomorecoolnicknames/remeizu/blob/main/SOURCE_INDEX.md) links device, common and kernel trees.

## Credits

LineageOS and CyanogenMod contributors, the original device-tree authors, and ReMeizu contributors. Copyright and license notices remain with their source files.
