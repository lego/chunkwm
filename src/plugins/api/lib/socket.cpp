#include <stdlib.h>
#include <string>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#include <iostream>

#include "lib/socket.h"

#define SOCKET_UNINITIALIZED 0
#define SOCKET_CLIENT 1
#define SOCKET_SERVER 2
#define SOCKET_BINDING 3

std::ostream& operator<<(std::ostream& os, const address_t& p) {
  return os << "<Address hostname=" << p.hostname << " port=" << p.port << ">";
}

bool operator ==(const address_t &lhs, const address_t &rhs) {
  return strcmp(lhs.hostname, rhs.hostname) == 0 && lhs.port == rhs.port;
}

int get_port(int sockfd) {
  struct sockaddr_in sin;
  socklen_t len = sizeof(sin);
  if (getsockname(sockfd, (struct sockaddr *)&sin, &len) == -1)
    return -1;
  return ntohs(sin.sin_port);
}

int create_socket_binding(int port) {
  // FIXME: assert port >= 0

  int file_descriptor;
  struct sockaddr_in serv_addr;
  file_descriptor = socket(AF_INET, SOCK_STREAM, 0);
  if (file_descriptor < 0)
    return COULDNT_OPEN;
  bzero((char *) &serv_addr, sizeof(serv_addr));
  serv_addr.sin_family = AF_INET;
  serv_addr.sin_addr.s_addr = INADDR_ANY;
  serv_addr.sin_port = htons(port);
  int status = bind(file_descriptor, (struct sockaddr *) &serv_addr, sizeof(serv_addr));
  if (status != 0)
    return COULDNT_BIND;
  return file_descriptor;
}


int create_socket_connection(const char* server_address, int port_no) {
  int file_descriptor;
  struct sockaddr_in serv_addr;
  struct hostent *server;

  file_descriptor = socket(AF_INET, SOCK_STREAM, 0);
  if (file_descriptor < 0)
    return COULDNT_OPEN; // FIXME: might not be the right error
  server = gethostbyname(server_address);
  std::cerr << "Hostname = " << server_address << std::endl;
  if (server == NULL) {
    return NO_HOST;
  }
  bzero((char *) &serv_addr, sizeof(serv_addr));
  serv_addr.sin_family = AF_INET;
  bcopy((char *)server->h_addr,
        (char *)&serv_addr.sin_addr.s_addr,
        server->h_length);
  serv_addr.sin_port = htons(port_no);
  int status = connect(file_descriptor, (struct sockaddr *) &serv_addr, sizeof(serv_addr));
  if (status != 0)
    return COULDNT_CONNECT;
  return file_descriptor;
}


socket_t *socket_create() {
  socket_t *socket = new socket_t;
  socket->type = SOCKET_UNINITIALIZED;
  return socket;
}

int socket_destroy(socket_t *socket) {
  int status;
  if (socket->type == SOCKET_BINDING) {
    if ((status = shutdown(socket->file_descriptor, SHUT_RDWR)) < 0) {
      return COULDNT_CLOSE;
    }
  }

  delete socket;
  return 0;
}

int socket_bind(socket_t *socket, int port) {
  // FIXME: assert socket not initialized

  int status = create_socket_binding(port);
  if (status < 0) {
    return status;
  }
  socket->file_descriptor = status;

  status = get_port(socket->file_descriptor);
  if (status < 0) {
    return status;
  }
  socket->port = status;
  socket->type = SOCKET_BINDING;
  return socket->port;
}

int socket_connect(socket_t *socket, const char * server_address, int port) {
  // FIXME: assert socket not initialized
  int status = create_socket_connection(server_address, port);
  if (status < 0) {
    return status;
  }
  socket->file_descriptor = status;
  socket->type = SOCKET_CLIENT;
  return OK;
}

#define CLIENT_BUFFER 5
int socket_accept(socket_t *socket, socket_t *new_client) {
  // FIXME: assert client not initialized
  // FIXME: assert that the socket->type == SOCKET_BINDING

  int newsock_fd;

  // set the limit of clients that can be buffered to accept
  listen(socket->file_descriptor, CLIENT_BUFFER);

  struct sockaddr_in cli_addr;
  socklen_t clilen;
  clilen = sizeof(cli_addr);

  // accept a new client
  if ((newsock_fd = accept(socket->file_descriptor, (struct sockaddr *) &cli_addr, &clilen)) < 0) {
    return COULDNT_ACCEPT;
  }

  new_client->type = SOCKET_SERVER;
  new_client->file_descriptor = newsock_fd;
  // TODO: populate port if we need it, but we probably don't

  return OK;
}

int socket_read(socket_t *socket, packet_t *packet) {
  // FIXME: assert that the socket->type == SOCKET_CLIENT || SOCKET_SERVER

  int packet_len;
  packet_type_t packet_type;
  int status;

  // FIXME: make the errors more specific
  if ((status = read(socket->file_descriptor, &packet_len, sizeof(int))) < 0) {
    return COULDNT_READ;
  }

  if ((status = read(socket->file_descriptor, &packet_type, sizeof(int))) < 0) {
    return COULDNT_READ;
  }

  char *packet_data = new char[packet_len];
  if ((status = read(socket->file_descriptor, packet_data, packet_len)) < 0) {
    return COULDNT_READ;
  }

  packet->len = packet_len;
  packet->type = packet_type;
  packet->data = packet_data;

  return status;
}

int socket_write(socket_t *socket, packet_t *packet) {
  // FIXME: assert that the socket->type == SOCKET_CLIENT || SOCKET_SERVER

  int status;

  // FIXME: make the errors more specific
  if ((status = write(socket->file_descriptor, &packet->len, sizeof(int))) < 0) {
    return COULDNT_WRITE;
  }

  if ((status = write(socket->file_descriptor, &packet->type, sizeof(int))) < 0) {
    return COULDNT_WRITE;
  }

  if ((status = write(socket->file_descriptor, packet->data, packet->len)) < 0) {
    return COULDNT_WRITE;
  }

  return OK;
}
