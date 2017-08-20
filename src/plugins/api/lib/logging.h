#pragma once

#include <iostream>

typedef enum {
  PlugrDebug,
  PlugrInfo,
  PlugrWarn,
  PlugrError,
} logging_level_t;

template <typename T> std::ostream& operator<<(logging_level_t level, const T& arg) {
  if (level == PlugrDebug) {
    return std::cerr << "[DEBUG] Plugr: " << arg;
  } else if (level == PlugrInfo) {
    return std::cerr << "[INFO] Plugr: " << arg;
  } else if (level == PlugrWarn) {
    return std::cerr << "[WARN] Plugr: " << arg;
  } else if (level == PlugrError) {
    return std::cerr << "[ERROR] Plugr: " << arg;
  }
}

#define Debug(fmt, ...) fprintf(stderr, "[DEBUG] Plugr: " fmt, ## __VA_ARGS__)
#define Info(fmt, ...) fprintf(stderr, "[INFO] Plugr: " fmt, ## __VA_ARGS__)
#define Warn(fmt, ...) fprintf(stderr, "[WARN] Plugr: " fmt, ## __VA_ARGS__)
#define Error(fmt, ...) fprintf(stderr, "[ERROR] Plugr: " fmt, ## __VA_ARGS__)
