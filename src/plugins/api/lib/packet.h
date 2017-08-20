#pragma once

#include <iostream>

typedef enum packet_type {
  PACKET_REGISTER,
  PACKET_TERMINATION,
  PACKET_SUBSCRIBE,
  PACKET_UNSUBSCRIBE,
  PACKET_COMMAND,
  PACKET_QUERY,
  PACKET_EVENT,
} packet_type_t;

typedef struct {
  int len;
  packet_type_t type;
  void *data;
} packet_t;

std::ostream& operator<<(std::ostream& os, const packet_t& p);
