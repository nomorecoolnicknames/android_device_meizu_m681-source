# Build Station additive port into the meizu_m6 LineageOS 15.1 tree.
# Single clean lineage_m681 product; the legacy CM-14.1 lane is dropped (its
# product makefile is not shipped here) so no foreign-prefixed product registers.
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/lineage_m681.mk

COMMON_LUNCH_CHOICES := \
    lineage_m681-userdebug \
    lineage_m681-eng
