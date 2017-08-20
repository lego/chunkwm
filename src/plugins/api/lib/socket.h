#pragma once

#include "lib/packet.h"
#include <iostream>

typedef struct {
  int type;
  int port;
  int file_descriptor;
} socket_t;

#define HOSTNAME_SIZE 32

#define OK 0
#define COULDNT_OPEN -1
#define COULDNT_CONNECT -2
#define COULDNT_BIND -3
#define NO_HOST -4
#define ALREADY_USED -5
#define CONNECTION_TERMINATED -6
#define COULDNT_CLOSE -7
#define COULDNT_ACCEPT -8
#define COULDNT_READ -9
#define COULDNT_WRITE -10

// TODO: move this to a better place
typedef struct {
  char hostname[HOSTNAME_SIZE];
  uint16_t port;
} address_t;

std::ostream& operator<<(std::ostream& os, const address_t& p);
bool operator ==(const address_t &lhs, const address_t &rhs);

/**
 * Creates an uninitialized socket
 */
socket_t *socket_create();

/**
 * Destroys and cleans up a socket
 * @param  socket to destroy
 * @return        result. 0 is OK
 *                error if result < 0:
 *                  ...
 */
int socket_destroy(socket_t *socket);


/**
 * Binds a socket to a port. Initializes the socket
 * @param  socket an uninitialized socket
 *                will error if this socket has been initialized
 * @param  port   to bind to
 *                if 0, an open port be used and returned
 *
 * @return        port bound to
 *                error if result < 0:
 *                  COULDNT_OPEN
 *                  ...

 */
int socket_bind(socket_t *socket, int port);

/**
 * Connects a socket to a server. Initializes the socket
 * @param  socket         an uninitialized socket
 *                        will error if this socket has been initialized
 * @param  server_address to connect to
 * @param  port           to connect to
 * @return                status, 0 if OK
 *                        error if return < 0:
 *                          COULDNT_CONNECT
 *                          ...
 */
int socket_connect(socket_t *socket, const char * server_address, int port);

/**
 * Accepts new clients on a listening socket
 * @param  socket an initialized socket to wait for clients on
 * @param  output a buffer socket_t to write the new connection to if successful
 * @return        status
 *                error if return < 0:
 *                  COULDNT_ACCEPT
 *                  ...
 */
int socket_accept(socket_t *socket, socket_t *new_client);

/**
 * Reads data from a socket into a packet_t
 * @param  socket an initialized socket to read from
 * @param  output a buffer packet_t to write a result if successful
 * @return        status
 *                error if return < 0:
 *                  CONNECTION_TERMINATED
 *                  ...
 */
int socket_read(socket_t *socket, packet_t *output);

/**
 * Writes data to a socket
 * @param  socket an initialized socket to write to
 * @param  input  a packet_t to write
 * @return        status
 *                error if return < 0:
 *                  CONNECTION_TERMINATED
 *                  ...
 */
int socket_write(socket_t *socket, packet_t *input);
