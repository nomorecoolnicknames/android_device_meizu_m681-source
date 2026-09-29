#
# lineage_m681.mk — Meizu M3 Note CN (m681) / MT6755, LineageOS 20 (Android 13)
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

# Flyme 6.2.0.2A vendor inputs use Android 7.0 / API 24.
# Treble and VNDK are explicitly enabled without misreporting the shipping API.
PRODUCT_SHIPPING_API_LEVEL := 24
PRODUCT_FULL_TREBLE_OVERRIDE := true

PRODUCT_CHARACTERISTICS := nosdcard

# Boot animation matches the panel (FACT: 1080x1920, see BoardConfig.mk).
TARGET_BOOT_ANIMATION_RES := 1080

# Stock Flyme 6.2.0.2A build description and fingerprint.
PRODUCT_BUILD_PROP_OVERRIDES += \
    TARGET_DEVICE=m3note \
    PRIVATE_BUILD_DESC="meizu_m3note-user 7.0 NRD90M 1510540088 release-keys"

BUILD_FINGERPRINT := Meizu/meizu_m3note/m3note:7.0/NRD90M/1510540088:user/release-keys
