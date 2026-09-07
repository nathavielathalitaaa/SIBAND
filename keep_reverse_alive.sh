#!/bin/bash
while true; do
  adb reverse tcp:8000 tcp:8000 > /dev/null 2>&1
  sleep 3
done
