# Build Station: full Lineage common product config required for OTA install tools
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# LineageOS 15.1: inherit from lineage_m681 (not cm_m681).
$(call inherit-product, device/meizu/m681/lineage_m681.mk)

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
