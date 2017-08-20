#pragma once

#include <iostream>

typedef enum packet_type {
  REGISTER,
  TERMINATION,
  SUBSCRIBE,
  UNSUBSCRIBE,
  COMMAND,
  QUERY,
} packet_type_t;

typedef struct {
  int len;
  packet_type_t type;
  void *data;
} packet_t;

std::ostream& operator<<(std::ostream& os, const packet_t& p);
