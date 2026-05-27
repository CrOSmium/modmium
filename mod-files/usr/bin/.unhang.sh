#!/bin/bash
# while this is extremely silly, it does successfully unhang fake_dmserver so like
# whatever

while :; do
  cat /proc/$(pgrep fake_dmserver | head -n 1)/fd/1 2>/dev/null &
  kill $(ps aux | grep -F 'cat /proc' | awk '{print $2}' | sed '$d') 2>/dev/null # immediately cleans up the process because it won't exit otherwise
  sleep 10
done
