#!/usr/bin/env bash
set -euo pipefail

# Usage:
# sudo ./deploy-dotnet-systemd.sh --service fileuploader --publishDir /tmp/fileuploader_publish --appDir /opt/apps/fileuploader --dll FileUploader.WebApi.dll [--healthUrl http://127.0.0.1:7000/health/ready]

SERVICE=""
PUBLISH_DIR=""
APP_DIR=""
DLL=""
HEALTH_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service)    SERVICE="$2"; shift 2 ;;
    --publishDir) PUBLISH_DIR="$2"; shift 2 ;;
    --appDir)     APP_DIR="$2"; shift 2 ;;
    --dll)        DLL="$2"; shift 2 ;;
    --healthUrl)  HEALTH_URL="$2"; shift 2 ;;
    *) echo "Arg desconocido: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$SERVICE" ]] || { echo "--service requerido" >&2; exit 2; }
[[ -d "$PUBLISH_DIR" ]] || { echo "--publishDir no existe: $PUBLISH_DIR" >&2; exit 2; }
[[ -n "$APP_DIR" ]] || { echo "--appDir requerido" >&2; exit 2; }
[[ -n "$DLL" ]] || { echo "--dll requerido" >&2; exit 2; }

RELEASES_DIR="$APP_DIR/releases"
CURRENT_LINK="$APP_DIR/current"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
NEW_RELEASE="$RELEASES_DIR/$STAMP"

echo "==> Deploy $SERVICE"
echo "    PublishDir: $PUBLISH_DIR"
echo "    AppDir:     $APP_DIR"
echo "    NewRelease: $NEW_RELEASE"

mkdir -p "$RELEASES_DIR"
mkdir -p "$NEW_RELEASE"

# Copia publish al release
rsync -a --delete "$PUBLISH_DIR"/ "$NEW_RELEASE"/

# Validación básica: DLL existe
if [[ ! -f "$NEW_RELEASE/$DLL" ]]; then
  echo "ERROR: No encuentro DLL en release: $NEW_RELEASE/$DLL" >&2
  exit 1
fi

# Guardar release anterior para rollback
PREV_RELEASE=""
if [[ -L "$CURRENT_LINK" ]]; then
  PREV_RELEASE="$(readlink -f "$CURRENT_LINK" || true)"
fi

# Swap atómico: symlink current -> new_release
ln -sfn "$NEW_RELEASE" "$CURRENT_LINK"

# Restart service
systemctl restart "$SERVICE"

# Health check opcional
if [[ -n "$HEALTH_URL" ]]; then
  echo "==> Health check: $HEALTH_URL"
  for i in {1..25}; do
    if curl -fsS "$HEALTH_URL" >/dev/null; then
      echo "OK: healthy"
      exit 0
    fi
    sleep 1
  done

  echo "ERROR: healthcheck falló. Rollback..." >&2
  if [[ -n "$PREV_RELEASE" && -d "$PREV_RELEASE" ]]; then
    ln -sfn "$PREV_RELEASE" "$CURRENT_LINK"
    systemctl restart "$SERVICE" || true
    echo "Rollback a: $PREV_RELEASE"
  else
    echo "No hay release previo para rollback." >&2
  fi
  exit 1
fi

echo "OK: deploy aplicado (sin healthcheck)"
