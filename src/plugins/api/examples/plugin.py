#!/bin/env python3
"""
This is a WIP python file that operates as a ChunkWM plugin through the api-plugin
"""

import traceback
import socket
import struct
from functools import singledispatch
from enum import Enum

PORT = 36669

@singledispatch
def encodify(data):
    if data is None:
        return 0, bytes()
    raise Exception("Encoding of type implemented: got type %s" % type(data))
    return (None, None)

@encodify.register(str)
def _(data):
    return len(data) + 1, bytes(data + '\0', 'ascii')

@encodify.register(int)
def _(data):
    INT_SIZE = 4
    return INT_SIZE, data.to_bytes(INT_SIZE, byteorder='big')

class PacketType(Enum):
    REGISTER = 0
    TERMINATION = 1
    SUBSCRIBE = 2
    UNSUBSCRIBE = 3
    COMMAND = 4
    QUERY = 5
    EVENT = 6

class Subscriptions(Enum):
    WINDOW_CREATED = 0
    WINDOW_DESTROYED = 1

class Packet(object):
    """
    Wire protocol for plugin communication
    """

    STRUCT_FMT = "<II" # packet_len, packet_type

    def __init__(self, packet_type, data=None, data_bytes=None):
        # FIXME: assert packet_type is a PacketType value
        self.type = packet_type
        self.data = data
        self.data_bytes = data_bytes

    @property
    def size(self):
        data_len, _ = encodify(self.data)
        return data_len

    @classmethod
    def from_bytes(klass, packet_type, data_bytes):
        return klass(packet_type, data_bytes=data_bytes)

        # FIXME: interpret packet data here?
        if packet_type == PacketType.EVENT:
            data = struct.unpack("<I", data_bytes)
            return klass(packet_type, data)
        else:
            raise Exception("Unhandled receive type")

    def to_bytes(self):
        (data_len, data_bytes) = encodify(self.data)
        header = struct.pack(self.STRUCT_FMT, data_len, self.type.value)
        return header + data_bytes

    def __repr__(self):
        return "<Packet len={} type={} data_type={} data: {} >".format(self.size, self.type.name, type(self.data), self.data)

def Send(conn, packet):
    error = None
    try:
        print("Sending packet: {}".format(packet))
        conn.send(packet.to_bytes())
    except Exception as e:
        traceback.print_exc()
        error = e
        conn.close()
    return error

def Register(conn):
    Send(conn, Packet(PacketType.REGISTER, "python-border"))

def Subscribe(conn, subscription):
    Send(conn, Packet(PacketType.SUBSCRIBE, subscription.value))

def Unsubscribe(conn, subscription):
    Send(conn, Packet(PacketType.UNSUBSCRIBE, subscription.value))

def ReceiveEvent(conn):
    error = None
    try:
        print("Recieving packet")
        size = conn.recv(4)
        size = struct.unpack("<I", size)[0]
        packet_type = conn.recv(4)
        packet_type = struct.unpack("<I", packet_type)[0]
        packet_type = PacketType(packet_type)
        data = conn.recv(size)
        packet = Packet.from_bytes(packet_type, data)
        return packet
    except Exception as e:
        traceback.print_exc()
        error = e
        conn.close()
    return error


if __name__ == "__main__":
    conn = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    conn.connect(('localhost', PORT))
    try:
        Register(conn)
        Subscribe(conn, Subscriptions.WINDOW_CREATED)
        Unsubscribe(conn, Subscriptions.WINDOW_CREATED)

        while True:
            event = ReceiveEvent(conn)
            print(event)
            if isinstance(event, Exception):
                exit(1)

    finally:
        conn.close()
