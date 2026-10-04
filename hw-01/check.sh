#!/usr/bin/env bash
set -uo pipefail

PREFIX="${PREFIX:-khikmatov-02}"
APP_PORT="${APP_PORT:-8006}"
GREETING="${GREETING:-cloudlab}"

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --port) APP_PORT="$2"; shift 2 ;;
    --greeting) GREETING="$2"; shift 2 ;;
    *) echo "неизвестный параметр: $1"; exit 1 ;;
  esac
done

FAIL=0

LB_IP=$(yc load-balancer network-load-balancer get "$PREFIX-lb" --format json 2>/dev/null \
  | jq -r '.listeners[0].address // empty')

CODE=000
if [ -n "$LB_IP" ]; then
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$LB_IP" || true)
fi
if [ "$CODE" = "200" ]; then
  echo "✓ балансировщик отвечает: $CODE"
elif [ -z "$LB_IP" ]; then
  echo "✗ балансировщик $PREFIX-lb не найден"
  FAIL=1
else
  echo "✗ балансировщик не отвечает: код $CODE"
  FAIL=1
fi

WEB_TOTAL=$(yc compute instance list --format json \
  | jq "[.[] | select(.name | startswith(\"$PREFIX-web-\"))] | length")
HOSTS=""
if [ -n "$LB_IP" ]; then
  HOSTS=$(for i in $(seq 1 30); do
      curl -s --max-time 3 "http://$LB_IP" | grep -o "$GREETING on [a-z0-9-]*"
    done | awk '{print $3}' | sed "s/^$PREFIX-//" | sort -u | paste -sd ' ' -)
fi
SEEN=$(echo "$HOSTS" | wc -w)
if [ "$SEEN" -gt 1 ] && [ "$SEEN" -eq "$WEB_TOTAL" ]; then
  echo "✓ ответили машины ($SEEN из $WEB_TOTAL): $HOSTS"
else
  echo "✗ ответили машины ($SEEN из $WEB_TOTAL): ${HOSTS:-ни одна}"
  FAIL=1
fi

WEB_IP=$(yc compute instance get "$PREFIX-web-1" --format json 2>/dev/null \
  | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address // empty')
APP_IP=$(yc compute instance get "$PREFIX-app" --format json 2>/dev/null \
  | jq -r '.network_interfaces[0].primary_v4_address.address // empty')
ANSWER=""
if [ -n "$WEB_IP" ] && [ -n "$APP_IP" ]; then
  ANSWER=$(ssh -o BatchMode=yes -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    student@"$WEB_IP" "curl -s --max-time 5 http://$APP_IP:$APP_PORT")
fi
if [[ "$ANSWER" == *"$GREETING on $PREFIX-app"* ]]; then
  echo "✓ сервер приложения доступен с web-1: $APP_IP:$APP_PORT"
else
  echo "✗ сервер приложения недоступен с web-1"
  FAIL=1
fi

exit "$FAIL"
