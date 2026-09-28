#
# BoardConfig.mk — Meizu M3 Note CN (m681), MediaTek MT6755 (Helio P10)
# LineageOS 18.1 / Android 11 bring-up device tree.
#
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# ---------------------------------------------------------------------------
# EVIDENCE POLICY (see /srv/forge/android/CLAUDE.md §2)
# Every non-obvious number below carries the artifact it came from.
# FACT       = read off a file / image header / scatter on this disk.
# INFERENCE  = derived from one or more FACTs.
# HYPOTHESIS = untested; carries a falsification step.
#
# Companion report: /srv/forge/android/meizu-fleet/trees/M681_LOS20_TREE.md
# ---------------------------------------------------------------------------

DEVICE_PATH := device/meizu/m681

# ---------------------------------------------------------------------------
# Architecture
#
# FACT: MT6755 (Helio P10) is 8x Cortex-A53, AArch64, ARMv8.0-A. It has no
#   LSE atomics (FEAT_LSE is ARMv8.1-A). Inline LSE instructions outside the
#   runtime-gated __aarch64_* outline helpers fault with SIGILL on this part.
#   Campaign factbase: /srv/forge/android/meizu-fleet/factbase/mt6755_family.md
#   and repo commits 5ffa3a7 / c1a0cf1 (check-gsi-cpu LSE detection work).
#
# FACT: build/soong/cc/config/arm64_device.go:31-33 maps arch variant
#   "armv8-a" to exactly `-march=armv8-a` and nothing else, and
#   arm64_device.go:57-59 maps cpu variant "cortex-a53" to `-mcpu=cortex-a53`
#   (+ `-Wl,--fix-cortex-a53-843419`, arm64_device.go:120/145).
#   Neither enables +lse. The forbidden values in the same table are
#   "armv8-2a" (-march=armv8.2-a) and "cortex-a55"; NEITHER is used here.
#
# DO NOT change TARGET_ARCH_VARIANT to armv8-2a or TARGET_CPU_VARIANT to
# cortex-a55/kryo*/exynos-m*. That is an instant SIGILL storm on this SoC.
#
# VERIFIED AT THE ARTIFACT LEVEL, not just from soong sources: the generated
# out/soong/build.ninja contains zero `+lse` and zero `-m[no-]outline-atomics`,
# and the default compile variant is `android_arm64_armv8-a_cortex-a53`.
# Two modules do carry higher-than-v8.0 flags and DO land in the image —
# XNNPACK's armv8.2 microkernels inside libtflite.so (runtime-gated by
# cpuinfo_has_arm_neon_dot() / _fp16_arith(), 21 guard sites in
# external/XNNPACK/src/init.c) and /system/bin/crypto from
# system/extras/crypto-perf (-march=armv8-a+crypto, which is ARMv8.0 plus the
# optional Crypto Extensions, NOT ARMv8.1, so not an LSE concern).
# Full analysis: meizu-fleet/trees/M681_LOS20_TREE.md §2.1. Re-run the check
# with the command in §8 of that report after any toolchain or manifest bump.
# ---------------------------------------------------------------------------
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53

TARGET_USES_64_BIT_BINDER := true

# ---------------------------------------------------------------------------
# Board / platform identity
#
# FACT: LK reports `product: WT6755_66_SZ_L` over fastboot
#   (capture kaeru-fastboot-diag-m681-91HEBNL163XD-20260621-133749, quoted at
#   meizu-fleet/factbase/mt6755_family.md:259-262).
# FACT: the working LOS16 boot cmdline carries androidboot.hardware=mt6755,
#   which selects init.mt6755.rc and is required to mount /system
#   (gunwest-import/m6rom16/rom-work/device/meizu/m681/BoardConfig.mk:88-92).
# ---------------------------------------------------------------------------
TARGET_BOARD_PLATFORM := mt6755
TARGET_BOOTLOADER_BOARD_NAME := mt6755
TARGET_BOARD_PLATFORM_GPU := mali-t860mp2

TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true

BOARD_NAME := m681
TARGET_OTA_ASSERT_DEVICE := m681,m3note

# ---------------------------------------------------------------------------
# Screen
#
# FACT: 1080x1920 — device/meizu/mt6755-common tree and TWRP tree agree
#   (m681/twrp51-m681/device/meizu/m681/BoardConfig.mk:29-30,
#    gunwest-import/.../device/meizu/m681/BoardConfig.mk:56-57).
# NOTE: the panel model for m681 is NOT recorded anywhere in the campaign
#   factbase (verified by grep over STATUS/GRAND_PLAN/factbase). l681's
#   nt35695 is explicitly flagged "never use l681 artifacts as m681 truth"
#   (mt6755_family.md:303-304). Panel identity stays an open item.
# ---------------------------------------------------------------------------
TARGET_SCREEN_WIDTH := 1080
TARGET_SCREEN_HEIGHT := 1920
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888

# ---------------------------------------------------------------------------
# Partitions — A-only, no slots, no dynamic partitions, no super.
#
# FACT (ground truth = the stock Flyme scatter on disk,
#       /srv/forge/android/m681/Flyme6.2.0.2A/scatter.txt; sizes are the
#       deltas between consecutive start offsets):
#     recovery 0x00008000 -> para     0x01008000  => 0x01000000 =    16 MiB
#     custom   0x01088000 -> expdb    0x21088000  => 0x20000000 =   512 MiB
#     boot     0x2c300000 -> logo     0x2d300000  => 0x01000000 =    16 MiB
#     system   0x30000000 -> cache    0xd0000000  => 0xa0000000 =  2560 MiB
#     cache    0xd0000000 -> userdata 0xeb000000  => 0x1b000000 =   432 MiB
#   There is NO `vendor` entry in the stock scatter.
#
# FACT (bootloader cross-check): fastboot `getvar all` on 91HEBNL163XD
#   2026-06-21 reports boot 0x1000000, lk/lk2 0x100000, expdb 0xa00000
#   (mt6755_family.md:259-262). boot agrees with the scatter arithmetic.
#
# FACT (block-device map, from the running LOS16 fstab
#   gunwest-import/.../device/meizu/m681/rootdir/fstab.mt6755):
#     p1 recovery, p3 custom, p22 boot, p29 system, p30 cache, p31 userdata.
#
# CONTRADICTION, resolved: device/meizu/mt6755-common/BoardConfigCommon.mk:45
#   in the LOS16 tree sets BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
#   (32 MiB). The scatter says 16 MiB and the TWRP tree
#   (m681/twrp51-m681/.../BoardConfig.mk:17) also says 16777216. Ground truth
#   is the scatter + the shipping TWRP image; 32 MiB would overflow into
#   `para`. We use 16777216.
#
# userdata: FACT, GPT of 91HEBNL163XD read 2026-09-28 (both headers CRC-OK,
#   meizu-fleet/flash-m681-20260928.md, section GPT): p31 userdata
#   = sectors 7700480..30502878 = 22802399 * 512 = 11674828288 bytes; the
#   eMMC is 30535680 sectors (~15.6 GB). The old 27879521280 came from the
#   TWRP tree (m681/twrp51-m681/.../BoardConfig.mk:20) and assumed a 32 GB
#   eMMC — REJECTED. Only image-size assertions use it (no userdata.img is
#   built).
# ---------------------------------------------------------------------------
BOARD_FLASH_BLOCK_SIZE := 131072

BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 16777216
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2684354560
BOARD_CACHEIMAGE_PARTITION_SIZE := 452984832
BOARD_USERDATAIMAGE_PARTITION_SIZE := 11674828288

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4

# A-only. No A/B, no virtual A/B, no dynamic partitions, no super image.
#
# NOTE: PRODUCT_USE_DYNAMIC_PARTITIONS must NOT be assigned here — it is a
# product variable and build/make/core/product_config.mk marks it
# .KATI_READONLY before BoardConfig.mk is read ("cannot assign to readonly
# variable"). Leaving it alone is correct: it defaults to empty/false, which is
# exactly what an A-only device wants. Same reasoning for
# PRODUCT_BUILD_SUPER_PARTITION.
AB_OTA_UPDATER := false
BOARD_USES_RECOVERY_AS_BOOT := false
BOARD_BUILD_SYSTEM_ROOT_IMAGE := false

# ---------------------------------------------------------------------------
# Treble — FULL, with a real /vendor on the stock `custom` partition (p3).
# Owner directive 2026-09-24: every Meizu fleet tree goes full Treble, the way
# m95 (MX6) is.  Report: meizu-fleet/designs/TREBLE_M681_L681_20260924.md.
#
# WHERE /vendor LIVES — FACT, three independent artifacts agree on 512 MiB:
#   * stock scatter /srv/forge/android/m681/Flyme6.2.0.2A/scatter.txt:
#       custom 0x1088000 -> expdb 0x21088000  => 0x20000000 = 536870912 B;
#   * the raw read-back of p3 taken off 91HEBNL163XD before it was reused,
#     m681/backups/m681-custom-p3-20260824.img.gz: `gzip -l` uncompressed
#     536870912, ext4, md5 of the .gz 2b7b4e0cdbc74e4d8256f01ed007b434;
#   * the LOS16 daily driver already mounts p3 as a REAL /vendor since
#     2026-08-24 (gunwest-import/m6rom16/rom-work/device/meizu/m681/
#     BoardConfig.mk "Treble stage A" + rootdir/fstab.mt6755); before that p3
#     held 524 KiB of Flyme leftovers out of 496 MiB, /system/vendor then
#     measured 341 MiB.
#   p3 is the same partition m95 uses (`custom`, mmcblk0p3, 512 MiB), so no
#   repartitioning: cache->vendor and a cut from system are REJECTED as
#   unnecessary (they would cost a GPT rewrite for space p3 already has).
#
# VNDK: `current`, exactly as m95 (device/meizu/m95/BoardConfig.mk, "Treble +
#   VNDK 30" block): pinning 30 was measured on m95 and REJECTED — vendor
#   APEXes from hardware/interfaces and every vendor.30 image variant break
#   soong_build without a checked-in vendor snapshot.  m95 ships the v30 VNDK
#   APEX only to boot an OLD 18.1-built vendor.img; m681 has no such image
#   (its only Treble vendor was LOS16/Pie), so the extra APEX is not shipped.
#
# PRODUCT_FULL_TREBLE_OVERRIDE := true lives in lineage_m681.mk (the shipping
#   API level there stays the honest 24).  With it config.mk:668-676 sets
#   PRODUCT_FULL_TREBLE, and :683-695 turn on TREBLE_LINKER_NAMESPACES,
#   SEPOLICY_SPLIT and ENFORCE_VINTF_MANIFEST.
#
# The Nougat blob set is the one the LOS16 daily driver ran from this very
#   partition (vendor/meizu/m681, see device.mk "Vendor blobs").
# ---------------------------------------------------------------------------
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_PARTITION_SIZE := 536870912
BOARD_VNDK_VERSION := current

# Split property files: /vendor carries its own build.prop.
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# The N-era blobs are installed with PRODUCT_COPY_FILES (vendor/meizu/m681),
# so the ELF gate of Android 11+ has to be relaxed exactly as on m95
# (device/meizu/m95/BoardConfig.mk).  TECHNICAL DEBT, not a fix: nothing
# validates their DT_NEEDED at build time; the closure is checked with
# meizu-fleet/tools/treble-closure.py instead (report, section "closure").
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# ---------------------------------------------------------------------------
# Boot image geometry
#
# FACT — read directly out of the on-disk boot image
#   /srv/forge/android/mt6755-49/m681_49_pie_g1_1.img (Android boot header v0):
#     kernel_addr  0x40080000   => BOARD_KERNEL_BASE 0x40078000 (addr - 0x8000)
#     ramdisk_addr 0x45000000   => ramdisk_offset 0x04f88000
#     second_addr  0x40f00000   => second_offset  0x00e88000
#     tags_addr    0x44000000   => tags_offset    0x03f88000
#     page_size    2048
#     name         "1480869018"
#   The identical five values appear in the LOS16 BoardConfig that produces
#   the currently booting daily driver
#   (gunwest-import/.../device/meizu/m681/BoardConfig.mk:169-173) — two
#   independent artifacts, same numbers.
#
# FACT: mt6755_family.md:173-176 records the same kernel/ramdisk load
#   addresses and page size read back from partition p22 on the device, so
#   the geometry is confirmed on hardware, not just on disk.
# ---------------------------------------------------------------------------
BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x04f88000
BOARD_SECOND_OFFSET := 0x00e88000
BOARD_TAGS_OFFSET := 0x03f88000
BOARD_MKBOOTIMG_ARGS := --board 1480869018 --ramdisk_offset $(BOARD_RAMDISK_OFFSET) --second_offset $(BOARD_SECOND_OFFSET) --tags_offset $(BOARD_TAGS_OFFSET)

# Legacy MTK boot header: no header_version, no dtb in bootimg, no dtbo.
BOARD_BOOT_HEADER_VERSION := 0
BOARD_INCLUDE_DTB_IN_BOOTIMG :=
BOARD_INCLUDE_RECOVERY_DTBO :=

# FACT: the LOS16 cmdline that actually boots this device
#   (gunwest-import/.../device/meizu/m681/BoardConfig.mk:92).
#   androidboot.hardware=mt6755 is load-bearing (selects init.mt6755.rc);
#   clk_ignore_unused is the MTK clk-gate workaround carried since the
#   3.18 m6-graft. selinux=permissive is honest about where sepolicy stands.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.hardware=mt6755 androidboot.selinux=permissive androidboot.usb.config=adb buildvariant=userdebug clk_ignore_unused

# First-stage mount: /system and /vendor are by-name paths in rootdir/etc/
# fstab.mt6755 (fleet decision 2026-09-25, same as M6/M6T); the reasoning and
# the boot marker are in that file.
#
# androidboot.partition_map is deliberately NOT on the cmdline any more.
# FACT (init/devices.cpp:405-430, block_dev_initializer.cpp:79-97): with by-name
#   paths it is inert.  With PARTNAME present the basename matches directly.
#   Without PARTNAME the map would let first stage FIND mmcblk0p29, but the
#   platform by-name link is only created from a PARTNAME (devices.cpp:405-413),
#   so the mount path would still not exist — it does not insure that case.
#   The real fallback for a no-PARTNAME kernel is raw nodes + a self-mapping
#   partition_map (both at once, recipe in the fstab header); the other is a
#   DT fstab node in the kernel, as m95 c507946d.
# (Kept out also because MTK LK appends its own cmdline: one dependency fewer.)

# ---------------------------------------------------------------------------
# Kernel — PREBUILT. This tree never compiles a kernel.
#
# FACT: the binary below is byte-identical to the kernel inside
#   /srv/forge/android/mt6755-49/m681_49_pie_g1_1.img — extracted pages
#   [2048, 2048+5487459) of that image and
#   /srv/forge/android/mt6755-49/kernel-mt6755-49/arch/arm64/boot/Image.gz-dtb
#   both hash to
#   sha256 ce9a58acab51a576d192a25fa5b623c4cfeaec2a21ae9dd320cf887d550335dd
#   (5487459 bytes). Copied here unmodified on 2026-09-16.
#
# FACT: that kernel is Linux 4.9.188, the "G1.1" mt6755 skeleton graft on the
#   m5c 4.9 base (kernel-mt6755-49/BRINGUP_STATE.md). It is the ONLY kernel on
#   this disk whose .config has CONFIG_BPF_SYSCALL=y and CONFIG_CGROUP_BPF=y,
#   i.e. the only one that could ever carry Android 13. See the kernel section
#   of meizu-fleet/trees/M681_LOS20_TREE.md.
#
# FACT: G1.1 has NEVER BEEN FLASHED (kernel-mt6755-49/BRINGUP_STATE.md, last
#   section; mt6755_family.md:162-165). Its predecessor G1 passed pre-MMU and
#   then died post-MMU in early initcalls with no capture. This prebuilt is
#   therefore a placeholder that makes the tree self-consistent, NOT a kernel
#   that is known to boot Android.
#
# The LOS kernel task takes the prebuilt branch only when KERNEL_SRC does not
# exist on disk (vendor/lineage/build/tasks/kernel.mk:127-148), so
# TARGET_KERNEL_SOURCE deliberately points at a path that is never synced.
# 2026-09-25 (Treble) — SUPERSEDED: the source is needed after all, the
# prebuilt stays what boot.img carries.
# FACT: audio.primary.mt6755.so (lib and lib64) NEEDs libtinycompress.so, and
#   external/tinycompress/Android.bp:46 takes header_libs device_kernel_headers
#   -> the Soong genrule generated_kernel_includes, i.e. `make -C
#   $(TARGET_KERNEL_SOURCE) headers_install` (vendor/lineage/build/soong/
#   Android.bp:21-24).  With no source it fails on .dummy_dep (m5s/meizu_m6
#   image runs of 2026-09-25, m95 on 2026-09-16).
# Same fix as m95 and meizu_m6:
#   * kernel/meizu/m681 is a symlink (made by hand, like kernel/meizu/m95) to
#     meizu-fleet/wt/kernel_m681_49_headers — a CLEAN worktree of
#     mt6755-49/kernel-mt6755-49 (the G1.1 4.9.188 tree whose Image.gz-dtb is
#     the prebuilt below), branch forge/m681-49-headers = HEAD 8ba6f2bfb + one
#     commit e2cadf911: host-csingle links with $(HOSTLDFLAGS) (m95 3522613e,
#     LESSONS.md §7).  Why not the G1.1 tree itself: it carries an in-tree
#     .config, and its host-csingle has no $(HOSTLDFLAGS), so fixdep could not
#     link in the sandbox (no GNU ld there, kernel.mk:264).
#     Checked outside Soong: make O=<ramdisk> ARCH=arm64 HOSTCC=<LOS clang>
#     HOSTLDFLAGS=-fuse-ld=lld headers_install -> rc=0, .fixdep.cmd carries
#     -fuse-ld=lld, usr/include/sound/compress_offload.h is produced.
#   * TARGET_FORCE_PREBUILT_KERNEL keeps kernel.mk on the prebuilt branch
#     (kernel.mk:180-190); without it source + config = a from-source build.
TARGET_NO_KERNEL := false
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_SOURCE := kernel/meizu/m681
TARGET_KERNEL_CONFIG := m681_49_defconfig
TARGET_FORCE_PREBUILT_KERNEL := true
TARGET_KERNEL_VERSION := 4.9
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/Image.gz-dtb
BOARD_KERNEL_IMAGE_NAME := kernel

# ---------------------------------------------------------------------------
# Recovery / fstab
# ---------------------------------------------------------------------------
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.mt6755
# No LOS recovery.img. FACT (build-treble-m681-images.log, run 6, 2026-09-25):
#   recovery.img = G1.1 kernel 5.5 MB + LOS20 recovery ramdisk 11.8 MB =
#   17266688 > 16777216 (p1), and vendorimage pulls recovery.img in (the
#   recovery-from-boot patch), so vendor.img never got built. p1 holds TWRP
#   3.7.0 (sha256 6e8d9de5…, readback 2026-09-28) — the rollback path of this
#   device, never overwritten; a LOS recovery would have nowhere to go anyway.
TARGET_NO_RECOVERY := true
BOARD_SUPPRESS_SECURE_ERASE := true
BOARD_CHARGER_SHOW_PERCENTAGE := true

# ---------------------------------------------------------------------------
# Wi-Fi — MediaTek WMT / conn_soc combo chip.
#
# FACT: the working LOS16 board config uses exactly these values, and kernel
#   diagnostics on the device show wlan0 and /dev/wmtWifi alive
#   (gunwest-import/.../device/meizu/m681/BoardConfig.mk:75-87).
# ---------------------------------------------------------------------------
BOARD_WLAN_DEVICE := MediaTek
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_mt66xx
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_mt66xx
WIFI_DRIVER_STATE_CTRL_PARAM := /dev/wmtWifi
WIFI_DRIVER_STATE_ON := 1
WIFI_DRIVER_STATE_OFF := 0

# ---------------------------------------------------------------------------
# SELinux
#
# The blob set is Nougat-era MTK; A13 public policy neverallows reject it
# wholesale, exactly as they did on the LOS16 lane
# (device/meizu/mt6755-common/BoardConfigCommon.mk:60-66). Runtime is
# permissive via the cmdline above. Keeping the build-time assertion off is
# honest about that; it must be revisited before any enforcing build.
# ---------------------------------------------------------------------------
SELINUX_IGNORE_NEVERALLOWS := true
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# ---------------------------------------------------------------------------
# Not-Qualcomm. Leaving these on drags SurfaceFlinger into QTI wrappers.
# ---------------------------------------------------------------------------
BOARD_USES_QCOM_HARDWARE := false
TARGET_USES_QCOM_BSP := false

# ---------------------------------------------------------------------------
# System properties file
# ---------------------------------------------------------------------------
TARGET_SYSTEM_PROP := $(DEVICE_PATH)/system.prop

# ---------------------------------------------------------------------------
# N-ABI shims of the vendor blob set: TARGET_LD_SHIM_LIBS for Mali EGL, gralloc
# and libgui_ext (2026-09-25).  Lives with the blobs, shared with l681.
# ---------------------------------------------------------------------------
include vendor/meizu/m681/BoardConfigVendor.mk
