LOCAL_PATH:= $(call my-dir)


include $(CLEAR_VARS)
LOCAL_MODULE    := ccStaticLibrary
LOCAL_SRC_FILES := prebuild/$(TARGET_ARCH_ABI)/libwicedmesh.a
LOCAL_C_INCLUDES := $(wildcard $(LOCAL_PATH)/include)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/include/common)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/include/hal)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/include/internal)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/include/stack)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/mesh_client_lib)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/mesh_libs)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH))
LOCAL_CFLAGS += -fno-stack-protector
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE    := native-lib

MY_CPP_LIST := $(wildcard $(LOCAL_PATH)/native-lib.c)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/trace.c)
#MY_CPP_LIST := $(wildcard $(LOCAL_PATH)/*.c)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/mesh_app.c)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/mesh_libs/mesh_main.c)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/mesh_client_lib/meshdb.c)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/mesh_client_lib/wiced_bt_mesh_db.c)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/mesh_client_lib/wiced_mesh_client.c)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/mesh_libs/aes.cpp)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/mesh_libs/aes_cmac.cpp)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/mesh_libs/ccm.cpp)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/mesh_libs/p_256_ecc_pp.c)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/mesh_libs/p_256_curvepara.c)
MY_CPP_LIST += $(wildcard $(LOCAL_PATH)/mesh_libs/p_256_multprecision.c)

LOCAL_SRC_FILES := $(MY_CPP_LIST:$(LOCAL_PATH)/%=%)

LOCAL_STATIC_LIBRARIES := ccStaticLibrary
LOCAL_CFLAGS += -fno-stack-protector
LOCAL_LDLIBS := -llog
LOCAL_C_INCLUDES := $(wildcard $(LOCAL_PATH)/include)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/include/common)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/include/hal)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/include/internal)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/include/stack)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/mesh_client_lib)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/mesh_libs)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH))
include $(BUILD_SHARED_LIBRARY)

APP_ABI := arm64-v8a armeabi-v7a x86 x86_64
