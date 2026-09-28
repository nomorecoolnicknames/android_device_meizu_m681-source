# This device is arm64; inherit core_64_bit before the phone stack so
# core_minimal doesn't lock us into ro.zygote=zygote32.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
# Switched from vendor/cm (14.1) to vendor/lineage (15.1 / Oreo).
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)
$(call inherit-product, device/meizu/m681/device.mk)

DEVICE_PACKAGE_OVERLAYS += device/meizu/m681/overlay

# 14.1 filter-out removed: Oreo (15.1) builds Java 8 natively; AudioFX,
# Recorder, Jelly, LiveWallpapersPicker and Updater are all compatible.

PRODUCT_BRAND := Meizu
PRODUCT_DEVICE := m681
PRODUCT_MANUFACTURER := Meizu
PRODUCT_MODEL := m681
PRODUCT_NAME := lineage_m681

# Pie: vendor/lineage does not default LINEAGE_BUILD from TARGET_DEVICE; set explicitly
LINEAGE_BUILD := m681

# Oreo / Treble declarations.
# PRODUCT_SHIPPING_API_LEVEL drives compatibility checks; 25 = Nougat 7.1
# (the level this device shipped at) so Oreo-level tests are advisory only.
PRODUCT_SHIPPING_API_LEVEL := 25

# Semi-treble: blobs remain under /system/vendor (no separate vendor
# partition). PRODUCT_FULL_TREBLE_OVERRIDE is false because the Nougat
# HAL ABI is not full-Treble compliant; this silences the strict VINTF check.
# Treble stage A (2026-08-24): the boot-image profile step is turned OFF.
# profman SIGBUSes on this build host, deterministically: the exact failing
# command reproduces by hand, all fifteen boot jars pass unzip -t, and it fails
# identically with the output written elsewhere.  It is a host-tool fault, it
# has nothing to do with the vendor partition being tested, and the profile is
# an optimisation rather than a requirement.
# TEMPORARY -- revisit before any build meant for daily use.
PRODUCT_USE_PROFILE_FOR_BOOT_IMAGE := false

PRODUCT_FULL_TREBLE_OVERRIDE := false

PRODUCT_GMS_CLIENTID_BASE := android-meizu

# 2026-07-12: with the full display shim cascade in place the bootanimation is
# physically visible but appeared UPSIDE-DOWN at hwrotation=180 (user-confirmed on
# 91HEBNL163XD), so the earlier 05-30 "panel inverted, correct with 180" assumption
# no longer holds on this HWC path — set 0 (native upright). Keep DSI/LCM untouched.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.hwrotation=0

PRODUCT_PROPERTY_OVERRIDES += \
    qemu.hw.mainkeys=0

ifneq ($(filter userdebug eng,$(TARGET_BUILD_VARIANT)),)
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.adb.secure=0 \
    ro.hardware.gralloc=mt6755 \
    ro.hardware.hwcomposer=mt6755 \
    ro.hardware.camera=mt6755 \
    ro.hardware.sensors=mt6755 \
    debug.sf.force_fbdev=0 \
    debug.sf.force_screen_on=0 \
    debug.sf.internal_fbdev_keep_on=0 \
    debug.sf.internal_fbdev_write=0 \
    debug.sf.intfb_copy_all=0 \
    debug.sf.intfb_sync_period=0 \
    debug.sf.disable_hwc=0 \
    debug.sf.disable_hwc_vds=0 \
    debug.sf.no_hw_fences=0 \
    debug.sf.no_hw_vsync=0 \
    debug.sf.hwc_set_diag=0 \
    debug.sf.skip_hwc_set=0 \
    debug.sf.skip_hwc_fbt_only=0 \
    debug.sf.internal_fbdev=0 \
    debug.sf.internal_fbdev_marker=0 \
    debug.sf.internal_fbdev_overlay=0 \
    debug.sf.internal_fbdev_meta=0 \
    debug.sf.intfb_period=0 \
    debug.sf.fb_force_bl=0 \
    debug.sf.mtkfb_kick=0 \
    debug.sf.hwc_set_limit=0 \
    debug.sf.hwc_set_period=0 \
    debug.sf.nobootanimation=0 \
    service.bootanim.exit=0 \
    sys.ipo.inlogo=0 \
    debug.hwc.trigger_by_vsync=1 \
    ro.sf.hwvsync.disable=0 \
    debug.sf.sw_vsync_fps=60 \
    ro.sf.triplebuf.disable=0 \
    persist.sys.usb.config=adb \
    persist.service.adb.enable=1 \
    qemu.hw.mainkeys=0 \
    persist.m681.bootdiag=1 \
    persist.m681.disable_colorfade=1 \
    persist.m681.modem.autostart=0
else
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.adb.secure=0 \
    persist.sys.usb.config=adb
endif

ifneq ($(strip $(M681_BOOTDIAG_ADB)),)
PRODUCT_DEFAULT_PROPERTY_OVERRIDES := $(filter-out \
    ro.adb.secure=0 \
    ro.hardware.gralloc=% \
    ro.hardware.hwcomposer=% \
    ro.hardware.camera=% \
    ro.hardware.sensors=% \
    debug.sf.force_fbdev=% \
    debug.sf.force_screen_on=% \
    debug.sf.internal_fbdev_keep_on=% \
    debug.sf.internal_fbdev_write=% \
    debug.sf.intfb_copy_all=% \
    debug.sf.intfb_sync_period=% \
    debug.sf.disable_hwc=% \
    debug.sf.disable_hwc_vds=% \
    debug.sf.no_hw_fences=% \
    debug.sf.no_hw_vsync=% \
    debug.sf.hwc_set_diag=% \
    debug.sf.skip_hwc_set=% \
    debug.sf.skip_hwc_fbt_only=% \
    debug.sf.internal_fbdev=% \
    debug.sf.internal_fbdev_marker=% \
    debug.sf.internal_fbdev_overlay=% \
    debug.sf.internal_fbdev_meta=% \
    debug.sf.intfb_period=% \
    debug.sf.fb_force_bl=% \
    debug.sf.mtkfb_kick=% \
    debug.sf.hwc_set_limit=% \
    debug.sf.hwc_set_period=% \
    debug.sf.nobootanimation=% \
    service.bootanim.exit=% \
    sys.ipo.inlogo=% \
    debug.hwc.trigger_by_vsync=% \
    ro.sf.hwvsync.disable=% \
    debug.sf.sw_vsync_fps=% \
    ro.sf.triplebuf.disable=% \
    persist.sys.usb.config=adb \
    persist.service.adb.enable=% \
    qemu.hw.mainkeys=% \
    persist.m681.bootdiag=% \
    persist.m681.disable_colorfade=% \
    persist.m681.modem.autostart=%,$(PRODUCT_DEFAULT_PROPERTY_OVERRIDES))
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.adb.secure=0 \
    ro.hardware.gralloc=mt6755 \
    ro.hardware.hwcomposer=mt6755 \
    ro.hardware.camera=mt6755 \
    ro.hardware.sensors=mt6755 \
    debug.sf.force_fbdev=0 \
    debug.sf.force_screen_on=0 \
    debug.sf.internal_fbdev_keep_on=0 \
    debug.sf.internal_fbdev_write=0 \
    debug.sf.intfb_copy_all=0 \
    debug.sf.intfb_sync_period=0 \
    debug.sf.disable_hwc=0 \
    debug.sf.disable_hwc_vds=0 \
    debug.sf.no_hw_fences=0 \
    debug.sf.no_hw_vsync=0 \
    debug.sf.hwc_set_diag=0 \
    debug.sf.skip_hwc_set=0 \
    debug.sf.skip_hwc_fbt_only=0 \
    debug.sf.internal_fbdev=0 \
    debug.sf.internal_fbdev_marker=0 \
    debug.sf.internal_fbdev_overlay=0 \
    debug.sf.internal_fbdev_meta=0 \
    debug.sf.intfb_period=0 \
    debug.sf.fb_force_bl=0 \
    debug.sf.mtkfb_kick=0 \
    debug.sf.hwc_set_limit=0 \
    debug.sf.hwc_set_period=0 \
    debug.sf.nobootanimation=0 \
    service.bootanim.exit=0 \
    sys.ipo.inlogo=0 \
    debug.hwc.trigger_by_vsync=1 \
    ro.sf.hwvsync.disable=0 \
    debug.sf.sw_vsync_fps=60 \
    ro.sf.triplebuf.disable=0 \
    persist.sys.usb.config=adb \
    persist.service.adb.enable=1 \
    qemu.hw.mainkeys=0 \
    persist.m681.bootdiag=1 \
    persist.m681.disable_colorfade=1 \
    persist.m681.modem.autostart=0
endif

# The 1080p/xxhdpi SystemUI path OOMs with the default 16 MB app heap while
# inflating battery/QS drawables. Put the same 3 GB phone heap profile into the
# ramdisk defaults as well as build.prop so bootimage-only patches fix it.
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    dalvik.vm.heapstartsize=8m \
    dalvik.vm.heapgrowthlimit=288m \
    dalvik.vm.heapsize=768m \
    dalvik.vm.heaptargetutilization=0.75 \
    dalvik.vm.heapminfree=512k \
    dalvik.vm.heapmaxfree=8m

# M681 camera: make the vendor feature-disable props visible before
# cameraserver/HAL init. rootdir/default.prop alone is not enough on the
# current bootimage-only patch path.
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    camera.disable_zsl_mode=1 \
    camera.zsdmode=0 \
    persist.m681.cam.no_fullraw=1 \
    persist.m681.cam.p1path=2 \
    persist.m681.cam.pre_p1magic=1 \
    persist.m681.cam.sync_tuning=1 \
    persist.m681.cam.deq_retry=0 \
    debug.featurepipe.enable=0 \
    debug.tworunpass2.enable=0 \
    debug.lowPowerVR.enable=0 \
    debug.forceFPS.enable=0 \
    debug.pass1.pdafon=0 \
    debug.pass1.rawtype=0 \
    debug.mtk_cam_zsdmfb_support=0 \
    debug.mtk_cam_zsdhdr_support=0 \
    debug.camera.vfb.disable=1 \
    debug.camera.eis.disable=1 \
    debug.eis.EMEnabled=0 \
    debug.eis.dump=0 \
    debug.eisDrv.dump=0 \
    debug.eis.disable=1 \
    persist.camera.eis.enable=0 \
    persist.camera.eis.disable=1 \
    persist.camera.vfb.enable=0 \
    persist.camera.vfb.disable=1 \
    cam.dumpnpipelog.enable=0 \
    camera.featurepipe.dumpvfb=0

# Build Station: early ADB bring-up defaults
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    persist.sys.usb.config=adb \
    persist.service.adb.enable=1 \
    persist.sys.adb.shell=/system/bin/sh

# Build Station: target device identity override
PRODUCT_NAME := lineage_m681
PRODUCT_DEVICE := m681
PRODUCT_BRAND := meizu
PRODUCT_MANUFACTURER := Meizu
PRODUCT_MODEL := m681
PRODUCT_RELEASE_NAME := m681
TARGET_OTA_ASSERT_DEVICE := m681,m3note
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=lineage_m681 \
    PRODUCT_DEVICE=m681 \
    TARGET_DEVICE=m681
