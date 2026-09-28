#
# lineage_m681.mk — Meizu M3 Note CN (m681) / MT6755, LineageOS 18.1 (Android 11)
#
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# arm64 with a 32-bit second ABI. core_64_bit must come before the phone
# stack so core_minimal does not pin ro.zygote=zygote32.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Device configuration.
$(call inherit-product, device/meizu/m681/device.mk)

# LineageOS common phone stack.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_DEVICE := m681
PRODUCT_NAME := lineage_m681
PRODUCT_BRAND := Meizu
PRODUCT_MODEL := M3 Note
PRODUCT_MANUFACTURER := Meizu

PRODUCT_GMS_CLIENTID_BASE := android-meizu

# ---------------------------------------------------------------------------
# Shipping API level + Treble.
#
# FACT: the newest stock image on disk is Flyme 6.2.0.2A, and its
#   /srv/forge/android/m681/Flyme6.2.0.2A/system/build.prop reads
#     ro.build.version.sdk=24
#     ro.build.version.release=7.0
#     ro.build.id=NRD90M
#     ro.build.fingerprint=Meizu/meizu_m3note/m3note:7.0/NRD90M/1510540088:user/release-keys
#   i.e. the vendor blob set this tree ships is API 24 / Nougat.  24 stays the
#   honest value (ro.product.first_api_level).
#
# Full Treble is switched on explicitly (owner directive 2026-09-24, "all fleet
# trees Treble, like m95").  build/make/core/config.mk:669-670 reads the
# override before the shipping level, so PRODUCT_FULL_TREBLE becomes true and
# config.mk:683-695 derive PRODUCT_TREBLE_LINKER_NAMESPACES,
# PRODUCT_SEPOLICY_SPLIT and PRODUCT_ENFORCE_VINTF_MANIFEST from it.  m95 does
# the same with shipping level 25 (device/meizu/m95/BoardConfig.mk).
# PRODUCT_USE_VNDK stays false at level 24 (config.mk:722-729 wants > 27), so
# BOARD_VNDK_VERSION is set explicitly in BoardConfig.mk, again as on m95.
# The /vendor partition facts are in BoardConfig.mk, block "Treble — FULL".
# ---------------------------------------------------------------------------
PRODUCT_SHIPPING_API_LEVEL := 24
PRODUCT_FULL_TREBLE_OVERRIDE := true

PRODUCT_CHARACTERISTICS := nosdcard

# Boot animation matches the panel (FACT: 1080x1920, see BoardConfig.mk).
TARGET_BOOT_ANIMATION_RES := 1080

# FACT: copied verbatim from the stock Flyme 6.2.0.2A
# /srv/forge/android/m681/Flyme6.2.0.2A/system/build.prop
# (ro.build.description / ro.build.fingerprint).
PRODUCT_BUILD_PROP_OVERRIDES += \
    TARGET_DEVICE=m3note \
    PRIVATE_BUILD_DESC="meizu_m3note-user 7.0 NRD90M 1510540088 release-keys"

BUILD_FINGERPRINT := Meizu/meizu_m3note/m3note:7.0/NRD90M/1510540088:user/release-keys

# This private product belongs to the API 30 platform; reject accidental A13 overlays.
ifneq ($(PLATFORM_SDK_VERSION),30)
$(error m681 lineage-18.1 requires PLATFORM_SDK_VERSION=30)
endif
