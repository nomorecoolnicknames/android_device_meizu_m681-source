LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := m681_nvram_wifi_repair
LOCAL_SRC_FILES := m681_nvram_wifi_repair.c \
                   m681_abi_guard.c
# m681_abi_guard.c carries compile-time ABI guards for local platform-header
# patches a repo sync would silently revert. It is hosted in this already-built
# module on purpose: a guard nobody compiles is worse than no guard.
LOCAL_HEADER_LIBRARIES := libhardware_headers
LOCAL_SHARED_LIBRARIES := libcutils liblog
LOCAL_MODULE_TAGS := optional
include $(BUILD_EXECUTABLE)
