#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
#  refresh_token.sh — Renueva el access_token OAuth2
#  Asignatura: Redes Avanzadas 1
#
#  El access_token de Google expira (~1 hora). Este script usa el
#  refresh_token persistente para obtener uno nuevo y lo imprime
#  por stdout, de modo que backup_gdrive.sh pueda capturarlo con:
#      ACCESS_TOKEN=$(bash refresh_token.sh)
#
#  Los mensajes de error van a stderr para no contaminar stdout.
# ─────────────────────────────────────────────────────────────────────

CONFIG_DIR="$HOME/backup_gdrive/config"
CREDS="$CONFIG_DIR/credentials.json"
TOKEN_FILE="$CONFIG_DIR/token.json"

# --- Validaciones previas -------------------------------------------
[ -f "$CREDS" ]      || { echo "ERROR: no existe $CREDS" >&2; exit 1; }
[ -f "$TOKEN_FILE" ] || { echo "ERROR: no existe $TOKEN_FILE. Ejecute auth_gdrive.sh primero." >&2; exit 1; }

CLIENT_ID=$(jq -r '.installed.client_id' "$CREDS")
CLIENT_SECRET=$(jq -r '.installed.client_secret' "$CREDS")
REFRESH_TOKEN=$(jq -r '.refresh_token' "$TOKEN_FILE")

if [ -z "$REFRESH_TOKEN" ] || [ "$REFRESH_TOKEN" = "null" ]; then
    echo "ERROR: token.json no contiene refresh_token. Ejecute auth_gdrive.sh nuevamente." >&2
    exit 1
fi

# --- Solicitar un access_token nuevo ----------------------------------
NEW_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "refresh_token=${REFRESH_TOKEN}" \
    -d "grant_type=refresh_token")

# --- Si Google devolvió un error, abortar -----------------------------
if echo "$NEW_TOKEN" | jq -e '.error' >/dev/null 2>&1; then
    echo "ERROR al refrescar token: $(echo "$NEW_TOKEN" | jq -r '.error_description // .error')" >&2
    echo "Sugerencia: si la app está en modo 'Prueba', el refresh_token expira a los 7 días." >&2
    echo "Vuelva a ejecutar auth_gdrive.sh para obtener uno nuevo." >&2
    exit 1
fi

# --- Fusionar: conserva el refresh_token y actualiza el access_token --
MERGED=$(jq -s '.[0] * .[1]' "$TOKEN_FILE" <(echo "$NEW_TOKEN"))
echo "$MERGED" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

# --- Entregar el access_token vigente por stdout -----------------------
jq -r '.access_token' "$TOKEN_FILE"
