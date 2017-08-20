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
internal pthread_mutex_t clients_mutex;
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

internal void client_handler(int client_no, client_t *client) {
  int result;
  packet_t request, response;

  while (true) {
    result = socket_read(client->conn, &request);
    if (should_exit) return;
    if (result <= 0) {
      Info("Client %d terminated connection\n", client_no);
      // TODO: handle client release
      pthread_mutex_lock(&clients_mutex);
      for (auto it = clients_connected.begin(); it != clients_connected.end(); it++) {
        if (*it == client)
          clients_connected.erase(it);
      }
      pthread_mutex_unlock(&clients_mutex);
      Debug("Clients left count=%lu\n", clients_connected.size());
      socket_destroy(client->conn);
      delete client;
      return;
    }

    std::cerr << client_no << ": got " << request << std::endl;
    switch (request.type) {
      default:
        // // return a failure
        // response.type = LOC_FAILURE;
        //
        // result = 1;
        // response.len = sizeof(result);
        // response.data = &result;
        break;
    }

    socket_write(client->conn, &response);
  }

  socket_destroy(client->conn);
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
    std::thread(client_handler, client_no++, client).detach();
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
};
CHUNKWM_PLUGIN_SUBSCRIBE(Subscriptions)

// NOTE(koekeishiya): Generate plugin
CHUNKWM_PLUGIN(PluginName, PluginVersion);
