#ifndef RUNNER_NETWORK_TRAFFIC_METER_H_
#define RUNNER_NETWORK_TRAFFIC_METER_H_

#include <cstdint>

struct NetworkByteCounters {
  uint64_t received;
  uint64_t sent;
  bool available;
  uint64_t source_id;
};

bool InstallMediaWinsockMeter();
NetworkByteCounters GetMediaWinsockCounters();
NetworkByteCounters GetActiveInterfaceCounters();

#endif  // RUNNER_NETWORK_TRAFFIC_METER_H_
