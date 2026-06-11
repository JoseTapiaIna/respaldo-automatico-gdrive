#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
#  cleanup_gdrive.sh — Limpieza de respaldos antiguos en Google Drive
#  Mejora opcional: elimina de Drive los respaldos con más de N días
#  para no consumir espacio de forma ilimitada.
# ─────────────────────────────────────────────────────────────────────

BASE_DIR="$HOME/backup_gdrive"
SCRIPT_DIR="$BASE_DIR/scripts"
LOG_FILE="$BASE_DIR/logs/backup_$(date +%Y%m).log"
GDRIVE_FOLDER="Respaldos_Linux"
MAX_DAYS=7
API="https://www.googleapis.com/drive/v3"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

log "------- LIMPIEZA DE RESPALDOS ANTIGUOS (mas de $MAX_DAYS dias) -------"

# --- Obtener token vigente ---------------------------------------------
ACCESS_TOKEN=$(bash "$SCRIPT_DIR/refresh_token.sh")
if [ -z "$ACCESS_TOKEN" ]; then
    log "ERROR: no se pudo obtener token de acceso."
    exit 1
fi

# --- Ubicar la carpeta de respaldos en Drive -----------------------------
FOLDER_ID=$(curl -s -G "$API/files" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "q=name='$GDRIVE_FOLDER' and mimeType='application/vnd.google-apps.folder' and trashed=false" \
    --data-urlencode "fields=files(id)" | jq -r '.files[0].id')

if [ "$FOLDER_ID" = "null" ] || [ -z "$FOLDER_ID" ]; then
    log "No existe la carpeta '$GDRIVE_FOLDER' en Drive. Nada que limpiar."
    exit 0
fi

# --- Buscar respaldos anteriores a la fecha de corte ---------------------
CUTOFF=$(date -u -d "-${MAX_DAYS} days" '+%Y-%m-%dT%H:%M:%S')

OLD_FILES=$(curl -s -G "$API/files" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "q=parents='$FOLDER_ID' and createdTime < '${CUTOFF}Z' and trashed=false" \
    --data-urlencode "fields=files(id,name)")

COUNT=$(echo "$OLD_FILES" | jq '.files | length')

if [ -z "$COUNT" ] || [ "$COUNT" = "null" ] || [ "$COUNT" -eq 0 ]; then
    log "No hay respaldos antiguos para eliminar."
    exit 0
fi

# --- Eliminar cada respaldo antiguo --------------------------------------
echo "$OLD_FILES" | jq -r '.files[] | .id + " " + .name' | while read -r FILE_ID FILE_NAME; do
    curl -s -X DELETE \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        "$API/files/$FILE_ID"
    log "Eliminado respaldo antiguo: $FILE_NAME (ID: $FILE_ID)"
done

log "------- LIMPIEZA COMPLETADA -------"
exit 0
