#include "raylib.h"                     // WARNING: Required for: LogType enum

// Check if config flags have been externally provided on compilation line
#if !defined(EXTERNAL_CONFIG_FLAGS)
    #include "config.h"                 // Defines module configuration flags
    #define ZIG__EXTERNAL_CONFIG_FLAGS 0
#else
    #define ZIG__EXTERNAL_CONFIG_FLAGS 1
#endif

#include "utils.h"

#if defined(PLATFORM_ANDROID)
    #include <errno.h>                  // Required for: Android error types
    #include <android/log.h>            // Required for: Android log system: __android_log_vprint()
    #include <android/asset_manager.h>  // Required for: Android assets manager: AAsset, AAssetManager_open()...
    #define ZIG__PLATFORM_ANDROID 1
#else
    #define ZIG__PLATFORM_ANDROID 0
#endif

#include <stdlib.h>                     // Required for: exit()
#include <stdio.h>                      // Required for: FILE, fopen(), fseek(), ftell(), fread(), fwrite(), fprintf(), vprintf(), fclose()
#include <stdarg.h>                     // Required for: va_list, va_start(), va_end()
#include <string.h>                     // Required for: strcpy(), strcat()

//----------------------------------------------------------------------------------
// Defines and Macros
//----------------------------------------------------------------------------------
#ifndef MAX_TRACELOG_MSG_LENGTH
    #define MAX_TRACELOG_MSG_LENGTH     256         // Max length of one trace-log message
#endif

#if defined(SUPPORT_TRACELOG)
    #define ZIG__SUPPORT_TRACELOG 1
#else
    #define ZIG__SUPPORT_TRACELOG 0
#endif

#if defined(SUPPORT_TRACELOG) && defined(SUPPORT_TRACELOG_DEBUG)
    #define ZIG__SUPPORT_TRACELOG_DEBUG 1
#else
    #define ZIG__SUPPORT_TRACELOG_DEBUG 0
#endif

#if defined(SUPPORT_STANDARD_FILEIO)
    #define ZIG__SUPPORT_STANDARD_FILEIO 1
#else
    #define ZIG__SUPPORT_STANDARD_FILEIO0
#endif

void zig__utils_c__TraceLog__ifdef_PLATFORM_ANDROID__switch_logType__android_log_vprint(int logType) {
#if defined(PLATFORM_ANDROID)
    switch (logType)
    {
        case LOG_TRACE: __android_log_vprint(ANDROID_LOG_VERBOSE, "raylib", text, args); break;
        case LOG_DEBUG: __android_log_vprint(ANDROID_LOG_DEBUG, "raylib", text, args); break;
        case LOG_INFO: __android_log_vprint(ANDROID_LOG_INFO, "raylib", text, args); break;
        case LOG_WARNING: __android_log_vprint(ANDROID_LOG_WARN, "raylib", text, args); break;
        case LOG_ERROR: __android_log_vprint(ANDROID_LOG_ERROR, "raylib", text, args); break;
        case LOG_FATAL: __android_log_vprint(ANDROID_LOG_FATAL, "raylib", text, args); break;
        default: break;
    }
#endif
}

