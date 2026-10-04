#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-khikmatov-02}"

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    *) echo "неизвестный параметр: $1"; exit 1 ;;
  esac
done

mine() {
  "$@" --format json | jq -r ".[] | select(.name | startswith(\"$PREFIX-\")) | .name"
}

for name in $(mine yc load-balancer network-load-balancer list); do
  yc load-balancer network-load-balancer delete "$name"
done

for name in $(mine yc load-balancer target-group list); do
  yc load-balancer target-group delete "$name"
done

for name in $(mine yc compute instance list); do
  yc compute instance delete "$name"
done

for name in $(mine yc vpc subnet list); do
  RT=$(yc vpc subnet get "$name" --format json | jq -r '.route_table_id // empty')
  if [ -n "$RT" ]; then
    yc vpc subnet update "$name" --disassociate-route-table
  fi
  yc vpc subnet delete "$name"
done

for name in $(mine yc vpc route-table list); do
  yc vpc route-table delete "$name"
done

for name in $(mine yc vpc gateway list); do
  yc vpc gateway delete "$name"
done

for name in $(mine yc vpc network list); do
  yc vpc network delete "$name"
done

echo "==> осталось с префиксом $PREFIX:"
for kind in "compute instance" "compute disk" "vpc address" "vpc subnet" "vpc route-table" \
    "vpc gateway" "vpc network" "load-balancer network-load-balancer" "load-balancer target-group"; do
  echo "$kind: $(mine yc $kind list | wc -l)"
done
