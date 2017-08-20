#pragma once

#include "lib/socket.h"
#include "subscriptions.h"

typedef struct {
  /**
   * Name of the client that has connected
   */
  char *name;

  /**
   * Socket connection to the client
   */
  socket_t *conn;

  /**
   * List of subscriptions the client has
   */
  std::vector<subscription_t> subscriptions;
} client_t;
