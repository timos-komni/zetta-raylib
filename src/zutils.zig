const std = @import("std");

const zutils_h = @cImport({
   @cInclude("zutils.h");
});

const __TRACELOG: ?*const fn(c_int, [*:0]const u8, ...) callconv(.C) void = if (zutils_h.ZIG__SUPPORT_TRACELOG == 1)&TraceLog else null;

const __TRACELOGD: ?*const fn(c_int, [*:0]const u8, ...) callconv(.C) void = if (zutils_h.ZIG__SUPPORT_TRACELOG_DEBUG == 1) &__TRACELOG else null;

export fn TRACELOG(level: c_int, ...) callconv(.C) void {
   if (__TRACELOG) |_TRACELOG| {
      var args = @cVaStart();
      _TRACELOG.*(level, @cVaArg(&args, [*:0]const u8), &args);
      @cVaEnd(&args);
   }
}

export fn TRACELOGD(...) callconv(.C) void {
   if (__TRACELOGD) |_TRACELOGD| {
      var args = @cVaStart();
      _TRACELOGD.*(zutils_h.LOG_DEBUG, @cVaArg(&args, [*:0]const u8), @ptrCast(&args));
      @cVaEnd(&args);
   }
}

export var logTypeLevel: c_int = zutils_h.LOG_INFO;

export var traceLog: zutils_h.TraceLogCallback = null;
export var zig_loadFileData: [*c]zutils_h.LoadFileDataCallback = null;
export var saveFileData: zutils_h.SaveFileDataCallback = null;
export var zig_loadFileText: [*c]zutils_h.LoadFileTextCallback = null;
export var saveFileText: zutils_h.SaveFileTextCallback = null;

//----------------------------------------------------------------------------------
// Functions to set internal callbacks
//----------------------------------------------------------------------------------
export fn SetTraceLogCallback(callback: zutils_h.TraceLogCallback) callconv(.C) void { traceLog = callback; } // Set custom trace log
export fn SetSaveFileDataCallback(callback: zutils_h.SaveFileDataCallback) callconv(.C) void { saveFileData = callback; } // Set custom file data saver
export fn SetSaveFileTextCallback(callback: zutils_h.SaveFileTextCallback) callconv(.C) void { saveFileText = callback; } // Set custom file text saver

// Set the current treshold (minimum) log level
export fn SetTraceLogLevel(logType: c_int) callconv(.C) void { logTypeLevel = logType; }

export fn TraceLog(logType: c_int, text: [*:0]const u8, ...) callconv(.C) void {
   if (comptime zutils_h.ZIG__SUPPORT_TRACELOG == 1) {
      // Message has level below current threshold, don't emit
      if (logType < logTypeLevel) return;

      var args = @cVaStart();

      if (traceLog != null) {
         traceLog.?(logType, text, @ptrCast(&args));
         @cVaEnd(&args);
         return;
      }

      if (comptime zutils_h.ZIG__PLATFORM_ANDROID == 1) {
         zutils_h.zig__utils_c__TraceLog__ifdef_PLATFORM_ANDROID__switch_logType__android_log_vprint(logType);
      } else {
         const buffer: [zutils_h.MAX_TRACELOG_MSG_LENGTH:0]u8 = std.mem.zeroes([zutils_h.MAX_TRACELOG_MSG_LENGTH:0]u8);

         _ = switch (logType) {
            zutils_h.LOG_TRACE => zutils_h.strcpy(@ptrCast(@constCast(&buffer)), "TRACE: "),
            zutils_h.LOG_DEBUG => zutils_h.strcpy(@ptrCast(@constCast(&buffer)), "DEBUG: "),
            zutils_h.LOG_INFO => zutils_h.strcpy(@ptrCast(@constCast(&buffer)), "INFO: "),
            zutils_h.LOG_WARNING => zutils_h.strcpy(@ptrCast(@constCast(&buffer)), "WARNING: "),
            zutils_h.LOG_ERROR => zutils_h.strcpy(@ptrCast(@constCast(&buffer)), "ERROR: "),
            zutils_h.LOG_FATAL => zutils_h.strcpy(@ptrCast(@constCast(&buffer)), "FATAL: "),
            else => {}
         };

         const textSize: c_uint = @intCast(zutils_h.strlen(@ptrCast(text)));
         _ = zutils_h.memcpy(@ptrFromInt(@intFromPtr(&buffer) + buffer.len), text, if (textSize < (zutils_h.MAX_TRACELOG_MSG_LENGTH - 12)) textSize else (zutils_h.MAX_TRACELOG_MSG_LENGTH - 12));
         _ = zutils_h.strcat(@ptrCast(@constCast(&buffer)), "\n");
         _ = zutils_h.vprintf(@ptrCast(@constCast(&buffer)), @ptrCast(&args));
         _ = zutils_h.fflush(zutils_h.stdout);

      }

      @cVaEnd(&args);

      if (logType == zutils_h.LOG_FATAL) std.c.exit(zutils_h.EXIT_FAILURE); // If fatal logging, exit program
   }
}

// Internal memory allocator
// NOTE: Initializes to zero by default
export fn MemAlloc(size: c_uint) callconv(.C) ?*anyopaque {
   const ptr: ?*anyopaque = zutils_h.RL_CALLOC(size, 1);
   return ptr;
}

// Internal memory reallocator
export fn MemRealloc(ptr: ?*anyopaque, size: c_uint) callconv(.C) ?*anyopaque {
   const ret: ?*anyopaque = zutils_h.RL_REALLOC(ptr, size);
   return ret;
}

// Internal memory free
export fn MemFree(ptr: ?*anyopaque) callconv(.C) void {
   zutils_h.RL_FREE(ptr);
}

// Load data from file into a buffer
// TODO unsigned char *LoadFileData(const char *fileName, int *dataSize)
pub extern fn LoadFileData(fileName: [*c]const u8, dataSize: [*c]c_int) [*c]u8;

// Unload file data allocated by LoadFileData()
export fn UnloadFileData(data: [*c]u8) callconv(.C) void {
   zutils_h.RL_FREE(data);
}

// Save data to file from buffer
export fn SaveFileData(fileName: [*c]const u8, data: ?*anyopaque, dataSize: c_int) bool {
   var success: bool = false;

   if (fileName != null) {
      if (saveFileData != null) {
         return saveFileData.?(fileName, data, dataSize);
      }
      if (comptime zutils_h.ZIG__SUPPORT_STANDARD_FILEIO == 1) {
         const file: [*c]zutils_h.FILE = zutils_h.fopen(fileName, "wb");

         if (file != null) {
            const count: c_int = @truncate(@as(isize, @bitCast(zutils_h.fwrite(data, @sizeOf(u8), @intCast(dataSize), file))));

            if (count == 0) {
               TRACELOG(zutils_h.LOG_WARNING, "FILEIO: [%s] Failed to write file", fileName);
            } else if (count != dataSize) {
               TRACELOG(zutils_h.LOG_WARNING, "FILEIO: [%s] File partially written", fileName);
            } else {
               TRACELOG(zutils_h.LOG_INFO, "FILEIO: [%s] File saved successfully", fileName);
            }

            const result: c_int = zutils_h.fclose(file);
            if (result == 0) success = true;
         }
      } else {
         TRACELOG(zutils_h.LOG_WARNING, "FILEIO: Standard file io not supported, use custom file callback");
      }
   } else {
      TRACELOG(zutils_h.LOG_WARNING, "FILEIO: File name provided is not valid");
   }

   return success;
}

// Export data to code (.h), returns true on success
// TODO bool ExportDataAsCode(const unsigned char *data, int dataSize, const char *fileName)
pub extern fn ExportDataAsCode(data: [*c]const u8, dataSize: c_int, fileName: [*c]const u8) bool;

// Load text data from file, returns a '\0' terminated string
// NOTE: text chars array should be freed manually
// TODO char *LoadFileText(const char *fileName)
pub extern fn LoadFileText(fileName: [*c]const u8) [*c]u8;

// Unload file text data allocated by LoadFileText()
export fn UnloadFileText(data: [*c]u8) callconv(.C) void {
   zutils_h.RL_FREE(data);
}

// Save text data to file (write), string must be '\0' terminated
export fn SaveFileText(fileName: [*c]const u8, text: [*c]u8) callconv(.C) bool {
   var success: bool = false;

   if (fileName != null) {
      if (saveFileText != null) {
         return saveFileText.?(fileName, text);
      }
      if (comptime zutils_h.ZIG__SUPPORT_STANDARD_FILEIO == 1) {
         const file: [*c]zutils_h.FILE = zutils_h.fopen(fileName, "wt");

         if (file == null) {
            const count: c_int = zutils_h.fprintf(file, "%s", text);

            if (count < 0) {
               TRACELOG(zutils_h.LOG_WARNING, "FILEIO: [%s] Failed to write text file", fileName);
            } else {
               TRACELOG(zutils_h.LOG_INFO, "FILEIO: [%s] Text file saved successfully", fileName);
            }

            const result: c_int = zutils_h.fclose(file);
            if (result == 0) success = true;
         } else {
            TRACELOG(zutils_h.LOG_WARNING, "FILEIO: [%s] Failed to open text file", fileName);
         }
      } else {
         TRACELOG(zutils_h.LOG_WARNING, "FILEIO: Standard file io not supported, use custom file callback");
      }
   } else {
      TRACELOG(zutils_h.LOG_WARNING, "FILEIO: File name provided is not valid");
   }

   return success;
}
