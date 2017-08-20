#include <iostream>

#include <lib/packet.h>

std::ostream& operator<<(std::ostream& os, const packet_t& p) {
  return os << "<Packet len=" << p.len << " type=" << p.type << " data=...>";
}
