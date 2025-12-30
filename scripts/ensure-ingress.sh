#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:?hostname requerido (ej: api.monfor.io)}"
SERVICE_URL="${2:?service url requerido (ej: http://127.0.0.1:7100)}"

CFG="/etc/cloudflared/config.yml"
TMP="$(mktemp)"

cp "$CFG" "$TMP"

if grep -qE "^\s*-\s*hostname:\s*$HOSTNAME\s*$" "$TMP"; then
  awk -v host="$HOSTNAME" -v svc="$SERVICE_URL" '
    BEGIN{inblock=0}
    {
      if ($0 ~ "^- hostname: "host"$") {inblock=1}
      if (inblock==1 && $0 ~ "^[[:space:]]*service:") {
        sub(/service:.*/, "    service: "svc)
        inblock=0
      }
      print
    }' "$TMP" > "${TMP}.new"
  mv "${TMP}.new" "$TMP"
else
  awk -v host="$HOSTNAME" -v svc="$SERVICE_URL" '
    {
      if ($0 ~ "^- service: http_status:404") {
        print "  - hostname: "host
        print "    service: "svc
        print ""
      }
      print
    }' "$TMP" > "${TMP}.new"
  mv "${TMP}.new" "$TMP"
fi

cloudflared --config "$TMP" tunnel ingress validate >/dev/null

if ! cmp -s "$CFG" "$TMP"; then
  cp "$TMP" "$CFG"
  systemctl restart cloudflared
  echo "UPDATED: $HOSTNAME -> $SERVICE_URL"
else
  echo "OK: sin cambios para $HOSTNAME"
fi

rm -f "$TMP"
