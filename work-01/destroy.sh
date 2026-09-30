#!/usr/bin/env bash

PREFIX=khikmatov-02
VM_COUNT=2

for i in $(seq 1 "$VM_COUNT"); do
  if yc compute instance get "$PREFIX-app-$i" >/dev/null 2>&1; then
    yc compute instance delete "$PREFIX-app-$i"
  fi
done

if yc vpc subnet get "$PREFIX-subnet" >/dev/null 2>&1; then
  yc vpc subnet delete "$PREFIX-subnet"
fi

if yc vpc network get "$PREFIX-net" >/dev/null 2>&1; then
  yc vpc network delete "$PREFIX-net"
fi

yc compute instance list
yc vpc network list
yc compute disk list