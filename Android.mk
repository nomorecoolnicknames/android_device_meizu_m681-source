LOCAL_PATH:= $(call my-dir)

ifneq ($(filter m681, $(TARGET_DEVICE)),)

# Two includes, both load-bearing.
#
# 1. first-makefiles-under: m681 previously had NO device Android.mk at all, so
#    the module finder descended and picked up device/meizu/m681/nvram/Android.mk
#    (m681_nvram_wifi_repair) and device/meizu/m681/wpa_supplicant_8_lib/Android.mk
#    (lib_driver_cmd_mt66xx) directly. Adding this file makes the finder stop
#    here instead of descending, so without this line both modules would silently
#    vanish -- and lib_driver_cmd_mt66xx is the wpa_supplicant driver-command
#    library, i.e. WiFi. Keep it first, exactly as meizu_m6/M6T do.
#
# 2. vendor/mediatek/ril: this is what actually defines libril and rild for this
#    device. BOARD_PROVIDES_LIBRIL / ENABLE_VENDOR_RIL_SERVICE only switch the
#    AOSP versions OFF (hardware/ril/libril/Android.mk:3 ifneq,
#    hardware/ril/rild/Android.mk:3 ifndef); the MTK replacements live in
#    vendor/mediatek/ril/{libril,rild}/Android.mk behind the matching ifeq. But
#    vendor/mediatek/Android.mk only includes symbols/, combo_loader/ and
#    wlan/wifi_hal/ for this device branch -- never ril/ -- so without this line
#    the switch means "delete libril" rather than "swap libril", and ckati fails:
#      hardware/ril/reference-ril/Android.mk: error: "libreference-ril
#      (SHARED_LIBRARIES android-arm64) missing libril (SHARED_LIBRARIES android-arm64)"
#    (reference-ril is ungated and always requires libril.)
#
# meizu_m6 and M6T are NOT broken by the same config: each carries this identical
# include at device/meizu/{meizu_m6,M6T}/Android.mk:6. m681 was simply missing the
# file. Verified: a clean parse of lineage_meizu_m6 defines libril and rild from
# MODULES-IN-vendor-mediatek-ril. This is therefore the tree's established
# convention -- device-local and device-scoped by construction -- which is why the
# fix belongs here and not in vendor/mediatek/Android.mk.
include $(call first-makefiles-under,$(LOCAL_PATH))
include vendor/mediatek/ril/Android.mk

endif
