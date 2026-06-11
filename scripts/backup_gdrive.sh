#!/bin/bash
# ═════════════════════════════════════════════════════════════════════
#  backup_gdrive.sh — Sistema de respaldo automático a Google Drive
#  Asignatura: Redes Avanzadas 1
#
#  Flujo de cada ejecución:
#    1. Comprime SOURCE_DIR en un .tar.gz con fecha y hora
#    2. Renueva el access_token OAuth2 (refresh_token.sh)
#    3. Busca (o crea) la carpeta destino en Google Drive
#    4. Sube el archivo mediante uploadType=multipart
#    5. Elimina el temporal y registra todo en el log mensual
#
#  Diseñado para ejecutarse manualmente o de forma automática vía cron.
# ═════════════════════════════════════════════════════════════════════

# --- Configuración ----------------------------------------------------
BASE_DIR="$HOME/backup_gdrive"
SCRIPT_DIR="$BASE_DIR/scripts"
LOG_FILE="$BASE_DIR/logs/backup_$(date +%Y%m).log"
TEMP_DIR="$BASE_DIR/temp"
SOURCE_DIR="$HOME/datos"                        # << Directorio a respaldar
BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S).tar.gz"
GDRIVE_FOLDER="Respaldos_Linux"                 # Carpeta destino en Google Drive
API="https://www.googleapis.com/drive/v3"

# --- Función de log ----------------------------------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

mkdir -p "$BASE_DIR/logs" "$TEMP_DIR"
log "======= INICIO DE RESPALDO ======="

# --- 0. Validaciones previas -------------------------------------------
if [ ! -d "$SOURCE_DIR" ]; then
    log "ERROR: el directorio fuente $SOURCE_DIR no existe. Abortando."
    exit 1
fi

# --- 1. Comprimir directorio fuente --------------------------------------
log "Comprimiendo $SOURCE_DIR..."
tar -czf "$TEMP_DIR/$BACKUP_NAME" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" 2>>"$LOG_FILE"

if [ $? -ne 0 ]; then
    log "ERROR: falló la compresión. Abortando."
    exit 1
fi
log "Archivo creado: $TEMP_DIR/$BACKUP_NAME ($(du -h "$TEMP_DIR/$BACKUP_NAME" | cut -f1))"

# --- 2. Obtener token actualizado ----------------------------------------
ACCESS_TOKEN=$(bash "$SCRIPT_DIR/refresh_token.sh")
if [ -z "$ACCESS_TOKEN" ]; then
    log "ERROR: no se pudo obtener token de acceso. Revise refresh_token.sh."
    exit 1
fi
log "Token OAuth2 renovado correctamente."

# --- 3. Buscar o crear carpeta en Drive -----------------------------------
log "Buscando carpeta '$GDRIVE_FOLDER' en Google Drive..."
FOLDER_SEARCH=$(curl -s -G "$API/files" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "q=name='$GDRIVE_FOLDER' and mimeType='application/vnd.google-apps.folder' and trashed=false" \
    --data-urlencode "fields=files(id,name)")

FOLDER_ID=$(echo "$FOLDER_SEARCH" | jq -r '.files[0].id')

if [ "$FOLDER_ID" = "null" ] || [ -z "$FOLDER_ID" ]; then
    log "Carpeta no encontrada. Creando '$GDRIVE_FOLDER'..."
    FOLDER_RESP=$(curl -s -X POST "$API/files" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$GDRIVE_FOLDER\",\"mimeType\":\"application/vnd.google-apps.folder\"}")
    FOLDER_ID=$(echo "$FOLDER_RESP" | jq -r '.id')

    if [ "$FOLDER_ID" = "null" ] || [ -z "$FOLDER_ID" ]; then
        log "ERROR: no se pudo crear la carpeta. Respuesta: $FOLDER_RESP"
        exit 1
    fi
    log "Carpeta creada con ID: $FOLDER_ID"
else
    log "Carpeta encontrada con ID: $FOLDER_ID"
fi

# --- 4. Subir archivo a Google Drive ---------------------------------------
log "Subiendo $BACKUP_NAME a Google Drive..."
METADATA=$(printf '{"name":"%s","parents":["%s"]}' "$BACKUP_NAME" "$FOLDER_ID")

UPLOAD_RESP=$(curl -s -X POST \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -F "metadata=${METADATA};type=application/json;charset=UTF-8" \
    -F "file=@$TEMP_DIR/$BACKUP_NAME;type=application/gzip" \
    "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")

FILE_ID=$(echo "$UPLOAD_RESP" | jq -r '.id')

if [ "$FILE_ID" != "null" ] && [ -n "$FILE_ID" ]; then
    log "Respaldo subido correctamente. ID Drive: $FILE_ID"
else
    log "ERROR al subir el archivo. Respuesta: $UPLOAD_RESP"
    exit 1
fi

# --- 5. Limpiar archivos temporales ------------------------------------------
rm -f "$TEMP_DIR/$BACKUP_NAME"
log "Archivo temporal eliminado."
log "======= RESPALDO COMPLETADO ======="
exit 0
