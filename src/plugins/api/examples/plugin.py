#!/bin/env python3
"""
This is a WIP python file that operates as a ChunkWM plugin through the api-plugin
"""

import socket
import struct
from functools import singledispatch

PORT = 36669

@singledispatch
def encodify(data):
    raise "Encoding of type implemented: got type %s" % type(data)
    return (None, None)

@encodify.register(str)
def _(data):
    return len(data), bytes(data, 'ascii')

class Packet(object):
    """
    Wire protocol for plugin communication
    """

    STRUCT_FMT = "<II" # packet_len, packet_type

    def __init__(self, packet_type, data):
        self.type = packet_type
        self.data = data

    # @classmethod
    # def decodify(klass, data):
    #     return data

    # @classmethod
    # def from_bytes(klass, b):
    #     data = struct.unpack(klass.STRUCT_FMT, b)
    #     return klass(*klass.decodify(data))

    def to_bytes(self):
        (data_len, data_bytes) = encodify(self.data)
        header = struct.pack(self.STRUCT_FMT, data_len, self.type)
        return header + data_bytes

if __name__ == "__main__":
    conn = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    conn.connect(('localhost', PORT))
    try:
        conn.send(Packet(0, 'hello').to_bytes())
    finally:
        conn.close()
