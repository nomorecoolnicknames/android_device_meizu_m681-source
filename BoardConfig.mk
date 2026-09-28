DEVICE_PATH := device/meizu/m681
TARGET_MEIZU_MT675X_DEVICE := m681
BOARD_SECCOMP_POLICY := $(DEVICE_PATH)/seccomp

include device/meizu/mt6755-common/BoardConfigCommon.mk
include vendor/meizu/m681/BoardConfigVendor.mk

# Factory scatter: recovery 0x8000..0x1008000 = 16 MiB. The shared
# mt6755-common 32 MiB default exceeds this board's partition.
# Evidence: /srv/forge/android/m681/Flyme6.2.0.2A/scatter.txt.
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 16777216

# MTK vendor-ABI shims (mirror meizu_m6/BoardConfig.mk:58-92 — m681 previously had
# NONE, which is why hwcomposer/guiext could not resolve the legacy libgui/libui
# symbols: createBufferQueue(...IGraphicBufferAlloc...), IDumpTunnel::asInterface,
# GraphicBufferMapper::lock(int). Live-diagnosed on 91HEBNL163XD 2026-07-12; see
# device/meizu/m681/DISPLAY_SHIM_CASCADE.md. libmtkshim_ui itself is pulled in via
# device.mk PRODUCT_PACKAGES so hwcomposer.mt6755.so's DT_NEEDED is satisfied.)
TARGET_LD_SHIM_LIBS += \
    /vendor/lib/libcam_utils.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib/libcam.client.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib/libcam.camnode.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib/libeffecthal.base.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib/libjni_lomoeffect.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib/libvfb_render.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib/libMtkOmxVenc.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib/libmtk_mmutils.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib/libshowlogo.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib/libgui_ext.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib/libui_ext.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib64/libcam_utils.so|/vendor/lib64/libmtkshim_gui.so \
    /vendor/lib64/libcam.client.so|/vendor/lib64/libmtkshim_gui.so \
    /vendor/lib64/libcam.camnode.so|/vendor/lib64/libmtkshim_gui.so \
    /vendor/lib64/libeffecthal.base.so|/vendor/lib64/libmtkshim_gui.so \
    /vendor/lib64/libjni_lomoeffect.so|/vendor/lib64/libmtkshim_gui.so \
    /vendor/lib64/libvfb_render.so|/vendor/lib64/libmtkshim_gui.so \
    /vendor/lib64/libmtk_mmutils.so|/vendor/lib64/libmtkshim_gui.so \
    /vendor/lib64/libgui_ext.so|/vendor/lib64/libmtkshim_gui.so \
    /vendor/lib64/libui_ext.so|/vendor/lib64/libmtkshim_gui.so

# GPS/sensor daemon linker-ABI shims (live-diagnosed crash-loops, capture
# data_crashes_3v18_214541.txt): MPED's libmpe.sensorlistener.so wants N-era
# libgui SensorEventQueue/SensorManager (moved to libsensor in O — shim pulls
# libsensor into the load group); mtk_agpsd wants ICU-56 ucnv_* symbols (tree
# ships ICU 58.2 — shim forwards _56 -> _58). Both daemons are ELF32 only.
# See vendor/mediatek/symbols/{sensor,icu}.cpp.
TARGET_LD_SHIM_LIBS += \
    /vendor/lib/libmpe.sensorlistener.so|/vendor/lib/libmtkshim_sensor.so \
    /vendor/bin/mtk_agpsd|/vendor/lib/libmtkshim_icu.so

TARGET_DEVICE := m681
TARGET_OTA_ASSERT_DEVICE := m681,m3note
TARGET_VENDOR := meizu
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/fstab.mt6755
TARGET_SCREEN_WIDTH := 1080
TARGET_SCREEN_HEIGHT := 1920
# Old MTK display blobs on this device are far more stable with a 32-bit
# SurfaceFlinger process. The tree already builds both libsurfaceflinger ABIs;
# this only flips the executable path away from the crashing 64-bit binary.
TARGET_32_BIT_SURFACEFLINGER := true
# MTK GuiExt/HWC configures the primary display for three GUI buffers during
# boot. Keep FramebufferSurface aligned with that depth instead of the AOSP
# default 2-buffer queue, which correlates with the current timeline-primary
# fence stall on the first visible frame.
NUM_FRAMEBUFFER_SURFACE_BUFFERS := 3
# The current black-screen failure is no longer an early SF crash; the late
# display path stalls forever on unsignaled present/retire fences from the
# legacy MTK HWC stack. Run SurfaceFlinger without the sync framework so it
# stops waiting on fences this 3.10 vendor stack never completes correctly.
TARGET_RUNNING_WITHOUT_SYNC_FRAMEWORK := true
# M681 is an MTK WMT/conn_soc Wi-Fi device. Kernel diagnostics show wlan0 and
# /dev/wmtWifi are alive; keep framework/HAL build-time paths on MediaTek so
# supplicant uses MTK private driver commands instead of Broadcom bcmdhd ones.
BOARD_WLAN_DEVICE := MediaTek
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_mt66xx
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_mt66xx
WIFI_DRIVER_STATE_CTRL_PARAM := /dev/wmtWifi
WIFI_DRIVER_STATE_ON := 1
WIFI_DRIVER_STATE_OFF := 0
WIFI_DRIVER_OPERSTATE_PATH := /sys/class/net/wlan0/operstate
WIFI_DRIVER_STATE_CTRL_RETRIES := 8
WIFI_DRIVER_STATE_CTRL_RETRY_DELAY_US := 1000000
# v206: full cmdline matching the working v205 m6-graft boot (header-verified):
# androidboot.hardware=mt6755 is REQUIRED to mount /system + select init.mt6755.rc;
# clk_ignore_unused is the m6-graft clk-gate workaround; usb.config=adb for early ADB.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.selinux=permissive androidboot.hardware=mt6755 androidboot.usb.config=adb buildvariant=userdebug clk_ignore_unused
ifneq ($(strip $(M681_KERNEL_CMDLINE_EXTRA)),)
BOARD_KERNEL_CMDLINE += $(strip $(M681_KERNEL_CMDLINE_EXTRA))
endif
# ---------------------------------------------------------------------------
# LineageOS 15.1 / Oreo (8.1) — Treble A-only semi-treble flags
# Strategy: /vendor = /system/vendor symlink (no repartition).
# custom(p3) holds Flyme Nougat blobs at runtime, mapped via symlink.
# Reference: TREBLE_PIE_ROADMAP.md §2, OrangePi 4G-IOT 8.1 BSP pattern.
# ---------------------------------------------------------------------------

# VNDK — DISABLED for this A-only semi-treble Nougat-blob device.
# BOARD_VNDK_VERSION := current forces Soong to build `vendor` image variants
# of every vendor_available lib; this tree's frameworks/native has libgui
# (vendor_available) depending on libsensor which is NOT vendor_available, so
# soong_build fails: "dependency libsensor of libgui missing variant image:vendor".
# The proven meizu_m6 product in this same tree sets no BOARD_VNDK_VERSION, and
# m681 is PRODUCT_FULL_TREBLE_OVERRIDE := false (blobs under /system/vendor, no
# vendor partition), so VNDK is inappropriate here. Re-enable only once the
# frameworks vendor_available graph is made consistent.
# BOARD_VNDK_VERSION := current

# --- Treble stage A (2026-08-24): a REAL /vendor partition on custom(p3) ---
# p3 is 512 MiB and, measured on the device before this change, held 524 KiB of
# Flyme leftovers out of 496 MiB -- it is free space, not a live partition.  A
# raw gzipped backup of it is kept at
# m681/backups/m681-custom-p3-20260824.img.gz (md5 2b7b4e0cdbc74e4d8256f01ed007b434).
# /system/vendor measures 341 MiB, so it fits with ~170 MiB of headroom.
#
# TARGET_COPY_OUT_VENDOR is what makes the difference: unset it resolves to
# "system/vendor" (build/make/core/envsetup.mk), which is why every blob has
# been landing inside system.img.  Setting it to "vendor" both builds a
# vendor.img and removes the ramdisk /vendor -> /system/vendor symlink.
#
# This is stage A ONLY: PRODUCT_FULL_TREBLE_OVERRIDE stays false and
# PRODUCT_SHIPPING_API_LEVEL stays 25, so VNDK enforcement is NOT turned on.
# VNDK is unreachable for this blob set and is not required for a vendor
# partition -- PRODUCT_USE_VNDK is gated on the shipping API level, not on
# Treble (build/make/core/config.mk).
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_PARTITION_SIZE := 536870912

# A-only (non-A/B) — this device has no slot suffix or dynamic partitions.
AB_OTA_UPDATER := false

# Split system/vendor build properties (Oreo requirement).
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true

# SELinux policy: stock 3.10.72 kernel caps at policyvers 29.
# When the 3.18 (vgdn) kernel becomes the primary boot kernel, remove
# POLICYVERS and BOARD_SEPOLICY_M4DEFS to let the build default to 30.
# HYPOTHESIS: 3.18 kernel accepts policyvers 30 (unverified on m681 hw).
# Build Station 15.1 port: building against the 3.18 stocktruth kernel as the
# boot kernel, so per the note above the policyvers cap is lifted — default to 30.
# POLICYVERS=29 cannot serialize the Oreo ioctl-xperm (allowxperm) rules:
# "libsepol.avtab_write_item: policy version 29 does not support ioctl
# extendedpermissions rules". meizu_m6 sets no POLICYVERS and builds clean.
# If the m681 kernel rejects policyvers 30 at boot, re-pin here AND strip xperm.
# POLICYVERS := 29
# BOARD_SEPOLICY_M4DEFS += m681_legacy_policyvers=true

# Oreo sepolicy split: platform policy (system partition) goes in
# BOARD_PLAT_SEPOLICY_DIRS; vendor policy goes in BOARD_SEPOLICY_DIRS.
# For this semi-treble build both reside in the device tree.
BOARD_PLAT_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/plat
BOARD_SEPOLICY_DIRS += \
    $(DEVICE_PATH)/sepolicy \
    $(DEVICE_PATH)/sepolicy/vendor
BOARD_KERNEL_BASE := 0x40078000
BOARD_MKBOOTIMG_ARGS := --board 1480869018 --ramdisk_offset 0x04f88000 --second_offset 0x00e88000 --tags_offset 0x03f88000
BOARD_RAMDISK_OFFSET := 0x04f88000
BOARD_SECOND_OFFSET := 0x00e88000
BOARD_TAGS_OFFSET := 0x03f88000

# v206 (Build Station): build OUR m6-graft 3.18.140 kernel FROM SOURCE.
# WAS: a PREBUILT 3.10 stocktruth Image.gz-dtb (TARGET_PREBUILT_KERNEL +
# PRODUCT_COPY_FILES .../forge-m3note_defconfig/...:kernel) which shadowed the
# from-source path entirely — that is the "3.10 nonsense" we are removing.
# The boot geometry above (base 0x40078000; ramdisk/second/tags offsets; board
# 1480869018; full cmdline incl androidboot.hardware=mt6755 + clk_ignore_unused)
# is header-verified against the WORKING v205 m6-graft boot.img, so a source
# build with m681_defconfig assembles a boot.img with the same geometry as v205.
# vendor/cm/build/tasks/kernel.mk compiles arch/arm64/boot/Image.gz-dtb here.
M681_M6GRAFT_KERNEL_SOURCE := /srv/forge/android/m681/kernel-m681-m6base-3.18.140/kernel-3.18
TARGET_NO_KERNEL := false
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_SOURCE := $(if $(M681_KERNEL_SOURCE_OVERRIDE),$(M681_KERNEL_SOURCE_OVERRIDE),$(M681_M6GRAFT_KERNEL_SOURCE))
TARGET_KERNEL_CONFIG := $(if $(M681_KERNEL_CONFIG_OVERRIDE),$(M681_KERNEL_CONFIG_OVERRIDE),m681_defconfig)
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

# Build Station: target device identity override
TARGET_OTA_ASSERT_DEVICE := m681,m3note
BOARD_NAME := m681
TARGET_SYSTEM_PROP := device/meizu/m681/system.prop
# forge prebuilt kernel — активен ТОЛЬКО в дефолтной сборке (без M681_SFOS_BUILD=1)
ifneq ($(M681_SFOS_BUILD),1)
TARGET_NO_KERNEL := false
TARGET_KERNEL_SOURCE := kernel/meizu/meizu_m6/kernel-3.18
TARGET_KERNEL_CONFIG :=
TARGET_PREBUILT_KERNEL := device/meizu/m681/prebuilt-kernel/Image.gz-dtb
BOARD_KERNEL_IMAGE_NAME := kernel
PRODUCT_COPY_FILES += \
    device/meizu/m681/prebuilt-kernel/Image.gz-dtb:kernel
else
# SFOS build (M681_SFOS_BUILD=1): ядро ИЗ ИСХОДНИКОВ (m681-display-dsi-clk WIP) + SFOS-defconfig
TARGET_NO_KERNEL := false
TARGET_KERNEL_SOURCE := $(if $(M681_KERNEL_SOURCE_OVERRIDE),$(M681_KERNEL_SOURCE_OVERRIDE),$(M681_M6GRAFT_KERNEL_SOURCE))
TARGET_KERNEL_CONFIG := $(if $(M681_KERNEL_CONFIG_OVERRIDE),$(M681_KERNEL_CONFIG_OVERRIDE),m681_sfos_defconfig)
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb
endif

# ---- RIL (2026-07-27, kril lane) ----------------------------------------
# Use the in-tree MTK Oreo HIDL RIL wrapper (vendor/mediatek/ril) instead of
# the generic AOSP rild/libril. Mirrors meizu_m6/BoardConfig.mk:9-22 and
# M6T/BoardConfig.mk:11-21, which already ship this way; m681 was the only
# MT675x product in this tree not doing it.
#
# FACT: /vendor/bin/mtkrild, librilmtk.so, mtk-ril.so and rilproxy contain zero
# "android.hardware.radio" strings and no hidl/hwbinder DT_NEEDED — the stock
# socket stack can never publish IRadio, so Android 9 telephony had nothing to
# bind to ("Waited one second for android.hardware.radio@1.0::IRadio/slot1").
#
# TARGET_SPECIFIC_HEADER_PATH puts MTK's telephony/ril.h ahead of
# hardware/ril's. MTK's RIL_Env has 6 slots (+24 RequestProxyTimedCallback,
# +32 QueryMyChannelId, +40 QueryMyProxyIdByThread); AOSP's has 4. mtk-ril.so
# dereferences +32/+40, so with the AOSP header it reads past the struct into
# rild's .bss — the SIGSEGV the 15.1 lane worked around with a hand-written
# ril_env_shim.c. Using MTK's own header removes the need for that shim.
# vendor/mediatek/include contains only telephony/{ril.h,mtk_ril.h}, so this
# global header override shadows nothing else.
TARGET_SPECIFIC_HEADER_PATH := vendor/mediatek/include
BOARD_PROVIDES_RILD := true
BOARD_PROVIDES_LIBRIL := true
