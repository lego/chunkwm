# chunkwm api-plugin

A plugin for [chunkwm](https://github.com/koekeishiya/chunkwm/) to provide an extensible API protocol over sockets. With this, you can write plugins in other languages to run alongside chunkwm.

It operates a socket on port 36669, which is planned to be changed to use Unix socket files in order to prevent port collision.

## Ideas

### Internal window state management
Without direct access to the state of the windows, you have two options as a non-C plugin:
- Re-query on every time information is required, in a lazy fashion
- The plugin keeps an internal state of the windows

The ideal case is that the plugin library itself maintains the internal state, so as a plugin developer you don't need to worry about it. Unfortunately, that would require the same management logic to be implemented in every language with a library.

A mixture of both strategies is probably most ideal, where we maintain basic internal state and lazily load additional info.

As an MVP, it makes the most sense to just implement the protocol interface for the library in a way that abstracts away the socket communication (i.e. create an clean RPC interface)

## Protocol
(these haven't had much thought, very WIP)
### Data types

```
Event:
  command
  payload

Window:
  id
  title
  size
  position
  properties
    mainrole
    subrole

  application id
  space id
  display id

Application:
  id
  pid and psn ?
  name
  window ids

Space
  id
  window ids
  display id

Display
  id
  size
  position (in virtual display)
  properties
    arrangement

  window ids
  space ids
```

### Commands

#### Queries
- Windows on desktop
- Windows
