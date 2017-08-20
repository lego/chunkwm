#pragma once

#include <pthread.h>
#include <set>

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
   * Lock for RW of exposed client data
   */
  pthread_mutex_t lock;

  /**
   * List of subscriptions the client has
   */
  std::set<subscription_t> subscriptions;
} client_t;
