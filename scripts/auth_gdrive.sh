#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
#  auth_gdrive.sh — Autenticación OAuth2 con Google Drive (paso único)
#  Asignatura: Redes Avanzadas 1
#
#  Obtiene el par access_token / refresh_token mediante el flujo
#  "Authorization Code" para aplicaciones de escritorio.
#
#  NOTA: el flujo OOB (urn:ietf:wg:oauth:2.0:oob) que aparece en
#  guías antiguas fue BLOQUEADO por Google en 2022. Por eso este
#  script usa http://localhost como redirect_uri: el navegador
#  redirige a una página que no carga (es normal), pero el código
#  de autorización queda visible en la URL.
# ─────────────────────────────────────────────────────────────────────

CONFIG_DIR="$HOME/backup_gdrive/config"
CREDS="$CONFIG_DIR/credentials.json"
TOKEN_FILE="$CONFIG_DIR/token.json"

# --- Validaciones previas -------------------------------------------
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq no está instalado (sudo apt install jq)"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl no está instalado (sudo apt install curl)"; exit 1; }
[ -f "$CREDS" ] || { echo "ERROR: no existe $CREDS. Copie sus credenciales de Google Cloud primero."; exit 1; }

# --- Extraer client_id y client_secret del JSON de credenciales ------
CLIENT_ID=$(jq -r '.installed.client_id' "$CREDS")
CLIENT_SECRET=$(jq -r '.installed.client_secret' "$CREDS")
SCOPE="https://www.googleapis.com/auth/drive.file"
REDIRECT_URI="http://localhost"

if [ "$CLIENT_ID" = "null" ] || [ -z "$CLIENT_ID" ]; then
    echo "ERROR: el JSON de credenciales no tiene el formato esperado (.installed.client_id)."
    echo "Verifique que descargó credenciales de tipo 'Aplicación de escritorio'."
    exit 1
fi

# --- Paso 1: mostrar URL de autorización al usuario -------------------
AUTH_URL="https://accounts.google.com/o/oauth2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&response_type=code&access_type=offline&prompt=consent"

echo "=============================================="
echo "      AUTENTICACIÓN GOOGLE DRIVE (OAuth2)     "
echo "=============================================="
echo
echo "1) Abra la siguiente URL en el navegador de su PC:"
echo
echo "$AUTH_URL"
echo
echo "2) Inicie sesión con su cuenta de Google y acepte los permisos."
echo
echo "3) El navegador redirigirá a una dirección del tipo:"
echo "      http://localhost/?code=4/0AXXXXXXXX&scope=..."
echo "   La página mostrará un error de conexión: ES NORMAL."
echo "   Copie solamente el valor del parámetro 'code'"
echo "   (todo lo que está entre 'code=' y '&scope')."
echo
read -r -p "Pegue el código de autorización aquí: " AUTH_CODE

# El navegador codifica el código en la URL (4%2F... en vez de 4/...).
# Lo decodificamos automáticamente por si se copió tal cual:
AUTH_CODE=$(printf '%s' "$AUTH_CODE" | sed 's/%2F/\//g; s/%2f/\//g')

# --- Paso 2: intercambiar el código por tokens ------------------------
RESPONSE=$(curl -s -X POST https://oauth2.googleapis.com/token \
    -d "code=${AUTH_CODE}" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "redirect_uri=${REDIRECT_URI}" \
    -d "grant_type=authorization_code")

# --- Validar y guardar el token ---------------------------------------
if echo "$RESPONSE" | jq -e '.refresh_token' >/dev/null 2>&1; then
    echo "$RESPONSE" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    echo
    echo "OK: token guardado correctamente en $TOKEN_FILE"
    echo "    access_token  : válido por ~1 hora"
    echo "    refresh_token : se usará para renovar automáticamente"
else
    echo
    echo "ERROR: la respuesta de Google no contiene refresh_token."
    echo "Detalle de la respuesta:"
    echo "$RESPONSE" | jq .
    echo
    echo "Causas comunes:"
    echo " - El código expiró (úselo dentro de ~10 minutos) o ya fue usado."
    echo " - Su correo no está agregado como 'usuario de prueba' en la"
    echo "   pantalla de consentimiento OAuth de Google Cloud."
    echo " - El reloj del servidor está desincronizado (revisar: timedatectl)."
    exit 1
fi
