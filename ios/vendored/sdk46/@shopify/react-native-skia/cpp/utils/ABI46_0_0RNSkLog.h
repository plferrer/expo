//
// Created by Christian Falch on 26/08/2021.
//

#pragma once

#include <string>
#include <ABI46_0_0jsi/ABI46_0_0jsi.h>

#ifdef ANDROID
#include <android/log.h>
#endif

#ifdef TARGET_OS_IPHONE
#include <syslog.h>
#endif

namespace ABI46_0_0RNSkia {

using namespace ABI46_0_0facebook;

class ABI46_0_0RNSkLogger {
public:
  /**
   * Logs message to console
   * @param message Message to be written out
   */
  static void logToConsole(std::string message) {
#ifdef ANDROID
    __android_log_write(ANDROID_LOG_INFO, "ABI46_0_0RNSkia", message.c_str());
#endif

#ifdef TARGET_OS_IPHONE
    syslog(LOG_ERR, "%s\n", message.c_str());
#endif
  }

  /**
   * Logs to console
   * @param fmt Format string
   * @param ... Arguments to format string
   */
  static void logToConsole(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);

    static char buffer[512];
    vsnprintf(buffer, 512, fmt, args);
#ifdef ANDROID
    __android_log_write(ANDROID_LOG_INFO, "ABI46_0_0RNSkia", buffer);
#endif
#ifdef TARGET_OS_IPHONE
    syslog(LOG_ERR, "%s\n", buffer);
#endif
    va_end(args);
  }
  
  static void logToJavascriptConsole(jsi::Runtime& runtime, const std::string& message) {
    auto console = ABI46_0_0RNSkLogger::getJavascriptConsole(runtime).asObject(runtime);
    auto log = console.getPropertyAsFunction(runtime, "log");
    log.call(runtime, jsi::String::createFromUtf8(runtime, message));
  }
  
  static void warnToJavascriptConsole(jsi::Runtime& runtime, const std::string& message) {
    auto console = ABI46_0_0RNSkLogger::getJavascriptConsole(runtime).asObject(runtime);
    auto warn = console.getPropertyAsFunction(runtime, "warn");
    warn.call(runtime, jsi::String::createFromUtf8(runtime, message));
  }
  
private:
  static jsi::Value getJavascriptConsole(jsi::Runtime& runtime) {
    auto console = runtime.global().getProperty(runtime, "console");
    if(console.isUndefined() || console.isNull()) {
      jsi::detail::throwJSError(runtime, "Could not find console object.");
      return jsi::Value::undefined();
    }
    return console;
  }
};
} // namespace ABI46_0_0RNSkia
