LOCAL_PATH:= $(call my-dir)

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
LOCAL_MODULE := calibrator

include $(BUILD_EXECUTABLE)
