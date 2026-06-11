# Respaldo automático a Google Drive con Bash y cron

**Ramo:** Redes Avanzadas 1

## Integrantes

- Jose Tapia
- Martin Cortes

## ¿De qué se trata?

Proyecto de laboratorio que automatiza el respaldo de un directorio en un servidor Linux. Un script en Bash empaqueta la carpeta en un archivo `.tar.gz` y lo envía a Google Drive a través de su API REST, autenticándose mediante OAuth2. La tarea queda programada con cron para correr todos los días sin intervención del usuario, y cada ejecución deja registro en un archivo de log con fecha y hora.

## ¿Cómo funciona?

El sistema está formado por tres scripts que trabajan en cadena:

1. `auth_gdrive.sh` se ejecuta una única vez para vincular la cuenta de Google. Genera la URL de autorización, recibe el código que entrega Google y lo intercambia por los tokens de acceso.
2. `refresh_token.sh` renueva el token antes de cada respaldo, ya que Google los hace expirar aproximadamente cada una hora.
3. `backup_gdrive.sh` es el script principal: comprime la carpeta configurada, solicita un token vigente, ubica (o crea) la carpeta de destino en Drive y sube el archivo comprimido.

Los tokens quedan guardados en `config/token.json` y el historial de ejecuciones en la carpeta `logs/`.

## Requisitos previos

Linux con `bash`, `curl`, `jq`, `tar`, `gzip` y `cron` instalados, además de un proyecto en Google Cloud Console con la Google Drive API habilitada y credenciales OAuth de tipo aplicación de escritorio.

## Puesta en marcha

1. Clonar el repositorio y dar permisos de ejecución a los scripts con `chmod +x scripts/*.sh`.
2. Copiar el archivo de credenciales descargado desde Google Cloud Console a `config/credentials.json`.
3. Correr `auth_gdrive.sh` y seguir las instrucciones en pantalla para autorizar la cuenta (solo se hace la primera vez).
4. Lanzar `backup_gdrive.sh` de forma manual para validar que todo funciona, revisando la salida en `logs/`.
5. Programar la ejecución diaria en el crontab del usuario.

## Ejecución automática

Línea configurada en cron para que el respaldo corra todos los días a las 02:00 AM:

    0 2 * * * /bin/bash $HOME/backup_gdrive/scripts/backup_gdrive.sh >> $HOME/backup_gdrive/logs/cron.log 2>&1

## Notas de seguridad

Las credenciales (`credentials.json`) y los tokens (`token.json`) son información sensible: en el servidor se mantienen con permisos `600` y el `.gitignore` del proyecto impide que terminen publicados en el repositorio.
