#
# device.mk — Meizu M3 Note CN (m681) / MT6755, LineageOS 20 (Android 13)
#
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/meizu/m681

# ---------------------------------------------------------------------------
# Soong namespaces (device-tree isolation)
#
# FACT (measured 2026-09-16): Soong parses every Android.bp in the workspace
# for every product and has no TARGET_DEVICE guard, so a bp module declared in
# one device tree lands in installs-<product>.mk of ALL products — a plain
# `m nothing` for lineage_m5s carried 51 install-rule lines from
# device/meizu/m95 (27 modules), two of them colliding with real m5s blobs
# (vendor/lib{,64}/libperfservicenative.so, via the `stem:` of
# libm95shim_perfservice).  Modules of a namespace reach Make only for the
# products that list that namespace here
# (build/soong/cmd/soong_build/main.go:99-112 -> android/namespace.go:204 ->
# android/androidmk.go:919).  Each tree carries a root Android.bp with
# `soong_namespace {}`; this line is the other half of the pair.
# ---------------------------------------------------------------------------
PRODUCT_SOONG_NAMESPACES += \
    device/meizu/m681 \
    vendor/meizu/m681

# ---------------------------------------------------------------------------
# Screen density
#
# FACT: ro.sf.lcd_density=480 in the stock Flyme 6.2.0.2A build.prop
#   (/srv/forge/android/m681/Flyme6.2.0.2A/system/build.prop), consistent with
#   a 1080x1920 5.5" panel => xxhdpi.
# ---------------------------------------------------------------------------
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxhdpi

# Device-specific framework overlays.
DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# ---------------------------------------------------------------------------
# Ramdisk / fstab
#
# A13 first-stage init mounts every fstab entry carrying `first_stage_mount`
# and, if there is a /system entry, calls SwitchRoot("/system")
# (system/core/init/first_stage_mount.cpp:505-525). So the fstab must live in
# the BOOT ramdisk, not only in /vendor/etc.
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6755:$(TARGET_COPY_OUT_RAMDISK)/fstab.mt6755 \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6755:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6755

# ---------------------------------------------------------------------------
# VINTF
#
# Enforced now: PRODUCT_ENFORCE_VINTF_MANIFEST follows PRODUCT_FULL_TREBLE
# (build/make/core/config.mk:683-695), which lineage_m681.mk switches on.
# manifest.xml carries target-level 3 like m95's (Android 13 ships FCM 3..7
# only); it lists only HALs this device.mk installs — HIDL services with their
# own VINTF fragment are merged in by the build.
# ---------------------------------------------------------------------------
DEVICE_MANIFEST_FILE := $(LOCAL_PATH)/manifest.xml

# ---------------------------------------------------------------------------
# Wi-Fi / supplicant
# ---------------------------------------------------------------------------
# NOTE: `wpa_supplicant.conf` is NOT a module in Android 13 — putting it in
# PRODUCT_PACKAGES fails main.mk:1312 "includes non-existent modules". The
# device tree must ship the file itself.
PRODUCT_PACKAGES += \
    libwpa_client \
    wpa_supplicant \
    hostapd

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/wifi/wpa_supplicant.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant.conf \
    $(LOCAL_PATH)/wifi/p2p_supplicant.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant.conf

# wpa_supplicant service with the AIDL interface name the A13 framework asks
# for (m95 lesson 161682f; nothing else in this image defines the service —
# see the header of that rc).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/init.m681.wifi.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m681.wifi.rc

# ---------------------------------------------------------------------------
# Vendor HALs (full Treble).  AOSP passthrough implementations plus their
# binderized services, all installed in /vendor, each wrapping an MT6755 blob
# from vendor/meizu/m681.  The set and the versions are m95's
# (device/meizu/m95/device.mk, booted to the setup wizard on the same N-era
# MTK blob generation), minus what m681 cannot back yet:
#   bluetooth@1.0 — no 64-bit libbt-vendor.so in the blob set (only
#     lib/libbt-vendor.so, ELF32; lib64/libbluetooth_mtk.so exists).  m95
#     closed the same wall with a decoded forwarder (shims/bt_vendor.c); the
#     m681 32-bit blob has not been decoded, so no guess is shipped.
#   biometrics.fingerprint — see manifest.xml.
#   ir — the M3 Note has no IR blaster.
# manifest.xml lists exactly these HALs.
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-service \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.graphics.mapper@2.0-impl-2.1 \
    android.hardware.memtrack@1.0-impl \
    android.hardware.memtrack@1.0-service \
    android.hardware.renderscript@1.0-impl \
    android.hardware.power@1.0-impl \
    android.hardware.power@1.0-service \
    android.hardware.light@2.0-impl \
    android.hardware.light@2.0-service \
    android.hardware.vibrator@1.0-impl \
    android.hardware.vibrator@1.0-service \
    android.hardware.audio@2.0-impl \
    android.hardware.audio@2.0-service \
    android.hardware.audio.effect@2.0-impl \
    android.hardware.audio@6.0-impl \
    android.hardware.audio.effect@6.0-impl \
    android.hardware.keymaster@3.0-impl \
    android.hardware.keymaster@3.0-service \
    android.hardware.gatekeeper@1.0-service.software \
    android.hardware.drm@1.0-impl \
    android.hardware.drm@1.0-service \
    android.hardware.drm@1.3-service.clearkey \
    android.hardware.gnss@1.0-impl \
    android.hardware.gnss@1.0-service \
    android.hardware.camera.provider@2.4-impl \
    android.hardware.camera.provider@2.4-service \
    android.hardware.sensors@1.0-impl \
    android.hardware.sensors@1.0-service \
    android.hardware.wifi@1.0-service \
    libwifi-hal-mt66xx \
    wificond

# ---------------------------------------------------------------------------
# Libraries the N-era blobs NEED that a Treble vendor namespace cannot take
# from /system (lessons 5-7 of the m95 bring-up).  Closure measured with
# meizu-fleet/tools/treble-closure.py over vendor/meizu/m681/m681-vendor-blobs.mk
# (report: meizu-fleet/designs/TREBLE_M681_L681_20260924.md, "closure").
#
#   libgui_mt6755fwd  -> /vendor/lib{,64}/libgui.so, forwarder to libgui_vendor
#                        (vendor/meizu/m681/Android.bp): 46 consumers; libgui is
#                        VNDK-private, invisible to vendor code.     (lesson 6)
#   libcamera_client_vendor -> /vendor/lib{,64}/libcamera_client.so with
#                        VendorLegacyCompat.cpp (frameworks/av, branch
#                        meizu-legacy-vendor): 31 consumers; FACT (fleet-port
#                        §3 п.7) the m681 libsource.so imports exactly the two
#                        symbols that file adds.                     (lesson 7)
#   libstdc++.vendor  -> 85 consumers (bionic/libc/Android.bp:2034,
#                        vendor_available), same as m95.
#   libtinycompress, libtinyxml -> audio.primary.mt6755.so (vendor: true
#                        modules; m95 ships libtinyxml for mnld as well).
#                        libtinycompress needs the kernel source, see below.
#   libalsautils      -> audio.usb.mt6755.so (vendor: true defaults).
#
# Lesson 5 (no copy of a VNDK library in /vendor): FACT, the same closure run
# finds no blob whose name is a VNDK/LLNDK library, and none of the modules
# above is one — libgui_mt6755fwd shadows only the PRIVATE libgui, which the
# vendor namespace could not see anyway.
# Lesson 8 (vendor public.libraries.txt): the stock file ships unchanged
# (etc/public.libraries.txt: libMcClient.so, libMcRegistry.so; both are in
# the blob set, lib and lib64).  No app of this tree loads a vendor JNI
# library, so nothing is added.
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    libgui_mt6755fwd \
    libcamera_client_vendor \
    libstdc++.vendor \
    libtinyxml \
    libalsautils

# libtinycompress: audio.primary.mt6755.so (lib and lib64) NEEDs it.  It needs
# the kernel headers genrule, hence kernel/meizu/m681 + TARGET_FORCE_PREBUILT_KERNEL
# in BoardConfig.mk (2026-09-25; it had been dropped for one commit, 7a1e85e).
PRODUCT_PACKAGES += \
    libtinycompress

# ---------------------------------------------------------------------------
# Feature declarations. Only the ones backed by hardware that is FACT-verified
# working on this device today (M681_DAILY_DRIVER_STATUS.md rows 1-36).
#
# Deliberately NOT declared:
#   android.hardware.camera*   — both cameras are broken on 4.4 and the whole
#                                camera lane is open (STATUS row 15).
#   android.hardware.microphone — analog UL front yields exact zeros (row 8).
#   android.software.ipsec_tunnels / cgroup-BPF dependent features — no eBPF.
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/handheld_core_hardware.xml

# ---------------------------------------------------------------------------
# Vendor blobs — the real /vendor image on `custom` (p3).
#
# vendor/meizu/m681 (branch lineage-20-treble) holds the 836-file N-era set of
# the LOS16 daily driver, i.e. the userspace that last booted 91HEBNL163XD from
# this very partition; how it was generated and why the LOS16 copy and not the
# raw stock is in vendor/meizu/m681/Android.mk.  Its file list replaces the
# inventory proprietary-files.txt of this directory, which stays as the audited
# record of the stock image.
#
# `inherit-product`, not `-if-exists`: a full Treble build without the blob
# tree would produce a vendor.img with HAL services and nothing to wrap.
# ---------------------------------------------------------------------------
$(call inherit-product, vendor/meizu/m681/m681-vendor-blobs.mk)

# N-ABI shims of the same blob set (libm681shim_base, libmtkshim_ui,
# libm681shim_perfservice); their linker wiring is vendor/meizu/m681/
# BoardConfigVendor.mk, included from BoardConfig.mk.
$(call inherit-product, vendor/meizu/m681/m681-vendor-shims.mk)

PRODUCT_PACKAGES += \
    m681_vendor_symlinks
