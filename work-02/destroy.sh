#!/usr/bin/env bash
set -euo pipefail

PREFIX=khikmatov-02

if yc load-balancer network-load-balancer get "$PREFIX-lb" >/dev/null 2>&1; then
  yc load-balancer network-load-balancer delete "$PREFIX-lb"
fi

if yc load-balancer target-group get "$PREFIX-tg" >/dev/null 2>&1; then
  yc load-balancer target-group delete "$PREFIX-tg"
fi

yc compute instance list --format json \
  | jq -r ".[] | select(.name | startswith(\"$PREFIX-app-\")) | .name" \
  | while read -r name; do
      yc compute instance delete "$name"
    done

if yc compute disk get "$PREFIX-data" >/dev/null 2>&1; then
  yc compute disk delete "$PREFIX-data"
fi

for s in a b; do
  if yc vpc subnet get "$PREFIX-subnet-$s" >/dev/null 2>&1; then
    yc vpc subnet delete "$PREFIX-subnet-$s"
  fi
done

if yc vpc network get "$PREFIX-net" >/dev/null 2>&1; then
  yc vpc network delete "$PREFIX-net"
fi

echo "==> осталось:"
yc compute instance list
yc compute disk list
yc vpc network list
yc load-balancer network-load-balancer list
