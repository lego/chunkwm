#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <pthread.h>
#include <thread>
#include <vector>
#include <signal.h>

#include "../../api/plugin_api.h"
#include "../../common/accessibility/application.h"

#include "client.h"
#include "lib/packet.h"
#include "lib/socket.h"
#include "lib/logging.h"

#define internal static

internal const char *PluginName = "api";
internal const char *PluginVersion = "0.1.0";
internal chunkwm_api API;
internal pthread_t api_listener_thread;
internal socket_t *welcome_socket;

internal volatile bool should_exit = false;
internal pthread_mutex_t clients_mutex = PTHREAD_MUTEX_INITIALIZER;
internal std::vector<client_t *> clients_connected;

#define PORT 36669

internal void termination_handler(int sig) {
  // If we are terminating due to a SIGINT (not DeInit)
  if (sig == SIGINT) signal(SIGINT, NULL);
  should_exit = true;
  Debug("beginning termination sequence\n");
  socket_destroy(welcome_socket);
  for (auto it = clients_connected.begin(); it < clients_connected.end(); it++) {
    // TODO: clean up client and client socket
  }
  Debug("Done termination sequence\n");
}

internal void sigpipe_handler(int sig) {

}

internal void client_handler(client_t *client) {
  signal(SIGPIPE, sigpipe_handler);

  int result;
  packet_t request, response;
  client->lock = PTHREAD_MUTEX_INITIALIZER;
  subscription_t subscription;

  while (true) {
    result = socket_read(client->conn, &request);
    if (should_exit) return;
    if (result <= 0) {
      Info("Client %d terminated connection\n", client->id);
      break;
    }

    std::cerr << client->id << ": got " << request << std::endl;
    switch (request.type) {
    case PACKET_REGISTER:
      client->name = new char[request.len];
      strncpy(client->name, (char *) request.data, request.len);
      Debug("Client registered name=%s len=%d\n", client->name, request.len);
      break;
    case PACKET_SUBSCRIBE:
      pthread_mutex_lock(&client->lock);
      // FIXME: assert validity of subscription enum
      subscription = *(subscription_t *) request.data;
      Debug("Client %d subscribed to %d\n", client->id, subscription);
      client->subscriptions.insert(subscription);
      if (client->subscriptions.find(SUBSCRIPTION_WINDOW_FOCUSED) != client->subscriptions.end()) {
        Debug("Sanity check for focused being in at post command");
      }
      pthread_mutex_unlock(&client->lock);
      break;
    case PACKET_UNSUBSCRIBE:
      pthread_mutex_lock(&client->lock);
      // FIXME: assert validity of subscription enum
      subscription = *(subscription_t *) request.data;
      Debug("Client %d unsubscribed from %d\n", client->id, subscription);
      client->subscriptions.erase(subscription);
      pthread_mutex_unlock(&client->lock);
      break;
    default:
      Error("Client %d send unknown packet type=%d\n", client->id, request.type);
      break;
    }
  }

  // TODO: handle client release
  pthread_mutex_lock(&clients_mutex);
  for (auto it = clients_connected.begin(); it != clients_connected.end(); it++) {
    if (*it == client)
      clients_connected.erase(it);
  }
  pthread_mutex_unlock(&clients_mutex);
  Debug("Clients left count=%lu\n", clients_connected.size());
  socket_destroy(client->conn);
  // FIXME: delete client->name if not null
  // FIXME: do we need to destroy client->subscriptions
  delete client;
}

internal void *api_listener(void *) {
  signal(SIGUSR1, termination_handler);
  signal(SIGINT, termination_handler);

  Debug("API listener starting\n");

  int result;
  welcome_socket = socket_create();
  result = socket_bind(welcome_socket, PORT);
  if (result < 0) {
    std::cerr <<  "Failed to bind to port result=" << result << std::endl;
    return NULL;
  }
  Info("API listener bound to port=%d\n", PORT);

  socket_t* client_socket = socket_create();
  int client_no = 0;

  while (true) {
    if (should_exit) break;

    result = socket_accept(welcome_socket, client_socket);
    if (result < 0) {
      std::cerr << "Client connection failed, uh oh." << std::endl;
      return NULL;
    }

    Info("New client connected: client_id=%d\n", client_no);
    client_t *client = new client_t;
    client->conn = client_socket;
    client->id = client_no++;
    std::thread(client_handler, client).detach();
    client_socket = new socket_t;
  }

  Info("API listener ending\n");
  return NULL;
}

inline bool
StringsAreEqual(const char *A, const char *B)
{
    bool Result = (strcmp(A, B) == 0);
    return Result;
}

internal void send_event(client_t * client, subscription_t event) {
  packet_t packet;
  packet.len = 4;
  packet.type = PACKET_EVENT;
  int data = event;
  packet.data = &data;
  socket_write(client->conn, &packet);
  // FIXME: handle error
}

/*
 * NOTE(koekeishiya):
 * parameter: const char *Node
 * parameter: void *Data
 * return: bool
 * */
PLUGIN_MAIN_FUNC(PluginMain)
{
    Debug("Got event Node=%s\n", Node);

    if(StringsAreEqual(Node, "chunkwm_export_application_launched"))
    {
        macos_application *Application = (macos_application *) Data;
        return true;
    }
    else if(StringsAreEqual(Node, "chunkwm_export_application_terminated"))
    {
        macos_application *Application = (macos_application *) Data;
        return true;
    }
    else if(StringsAreEqual(Node, "chunkwm_export_window_focused"))
    {
        pthread_mutex_lock(&clients_mutex);
        for (auto it = clients_connected.begin(); it != clients_connected.end(); it++) {
          client_t *client = *it;
          pthread_mutex_lock(&client->lock);
          if (client->subscriptions.find(SUBSCRIPTION_WINDOW_FOCUSED) != client->subscriptions.end()) {
            Debug("Sending focused event to client %d", client->id);
            send_event(client, SUBSCRIPTION_WINDOW_FOCUSED);
          }
          pthread_mutex_unlock(&client->lock);
        }
        pthread_mutex_unlock(&clients_mutex);
        return true;
    }

    return false;
}

/*
 * NOTE(koekeishiya):
 * parameter: chunkwm_api ChunkwmAPI
 * return: bool -> true if startup succeeded
 */
PLUGIN_BOOL_FUNC(PluginInit)
{
    pthread_create(&api_listener_thread, NULL, api_listener, NULL);
    API = ChunkwmAPI;
    pthread_detach(api_listener_thread);
    return true;
}

PLUGIN_VOID_FUNC(PluginDeInit)
{
  Debug("Running DeInit\n");
  termination_handler(-1);
}

#define CHUNKWM_PLUGIN_API_VERSION 5

// NOTE(koekeishiya): Initialize plugin function pointers.
CHUNKWM_PLUGIN_VTABLE(PluginInit, PluginDeInit, PluginMain)

// NOTE(koekeishiya): Subscribe to ChunkWM events!
chunkwm_plugin_export Subscriptions[] =
{
    chunkwm_export_application_terminated,
    chunkwm_export_application_launched,
    chunkwm_export_window_created,
    chunkwm_export_window_destroyed,
    chunkwm_export_window_focused,
};
CHUNKWM_PLUGIN_SUBSCRIBE(Subscriptions)

// NOTE(koekeishiya): Generate plugin
CHUNKWM_PLUGIN(PluginName, PluginVersion);
