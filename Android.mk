LOCAL_PATH:= $(call my-dir)

#
# Calibrator
#
include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
		nvs.c \
		misc_cmds.c \
		calibrator.c \
		plt.c \
		ini.c

LOCAL_CFLAGS :=
LOCAL_C_INCLUDES := \
	$(LOCAL_PATH) \
	external/libnl/include

LOCAL_SHARED_LIBRARIES := libnl
LOCAL_MODULE_TAGS := eng
LOCAL_MODULE := calibrator

include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := scripts/wl12xx-tool.sh
LOCAL_MODULE_TAGS := eng
LOCAL_MODULE_PATH := $(local_target_dir)
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES := $(LOCAL_MODULE)
include $(BUILD_PREBUILT)

#
# UIM Application
#
#include $(CLEAR_VARS)

#LOCAL_C_INCLUDES:= \
#	$(LOCAL_PATH)/uim_rfkill/ \
#	external/bluetooth/bluez/

#LOCAL_SRC_FILES:= \
#	uim_rfkill/uim.c
#LOCAL_CFLAGS:= -g -c -W -Wall -O2 -D_POSIX_SOURCE
#LOCAL_SHARED_LIBRARIES:= libnetutils
#LOCAL_MODULE_TAGS := eng
#LOCAL_MODULE:=uim-util

#include $(BUILD_EXECUTABLE)
