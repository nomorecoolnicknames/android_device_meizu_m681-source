# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
# BoardConfig.mk — Meizu M3 Note CN (m681), MediaTek MT6755 (Helio P10)

DEVICE_PATH := device/meizu/m681

# MT6755 uses eight ARMv8.0 Cortex-A53 cores.
# LSE instructions require ARMv8.1 and must not be enabled for this target.
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

# A-only geometry: recovery 16 MiB, custom 512 MiB, boot 16 MiB, system 2560 MiB.
# There is no stock vendor or dynamic super partition.
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

# Treble uses the stock custom partition (mmcblk0p3, 512 MiB) for /vendor.
# VNDK is selected explicitly; the shipping API continues to describe the stock vendor ABI.
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

# Boot header v0: kernel 0x40080000, ramdisk 0x45000000, tags 0x44000000, page size 2048.
# The base and offsets below reproduce these addresses.
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

# The selected prebuilt contains the BPF interfaces needed by this Android branch.
# Kernel source and configuration are still required for UAPI headers.
# Force-prebuilt avoids unintentionally rebuilding the kernel during the Android build.
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
# Mount points of the nofail fstab entries on the system root: /nvdata (p7),
# /protect_f (p11), /protect_s (p12).  The A13 root is the system image; without
# these the second-stage mount_all has nowhere to mount them (m5c: same list).
BOARD_ROOT_EXTRA_FOLDERS := nvdata protect_f protect_s
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
