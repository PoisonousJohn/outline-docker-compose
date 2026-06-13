#!/bin/bash
set -euo pipefail

# Надежное определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR%/scripts}"
ENV_FILE="${PROJECT_DIR}/.env"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# 1. Проверяем наличие файла .env
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env file not found at $ENV_FILE" >&2
    exit 1
fi

# 2. Извлекаем переменные из .env
ZIP_PASSWORD=$(grep -v '^#' "$ENV_FILE" | grep -E '^ZIP_PASSWORD=' | head -1 | cut -d'=' -f2- | xargs)
YANDEX_OAUTH_TOKEN=$(grep -v '^#' "$ENV_FILE" | grep -E '^YANDEX_OAUTH_TOKEN=' | head -1 | cut -d'=' -f2- | xargs)

if [ -z "$ZIP_PASSWORD" ] || [ -z "$YANDEX_OAUTH_TOKEN" ]; then
    echo "ERROR: ZIP_PASSWORD or YANDEX_OAUTH_TOKEN is missing in .env" >&2
    exit 1
fi

# 3. Корректировка времени под МСК (UTC+3)
SERVER_TZ_OFFSET=$(date +%z | sed 's/+//')
if [ "$SERVER_TZ_OFFSET" = "0000" ] || [ "$(date +%Z)" = "UTC" ]; then
    BACKUP_HOUR=1
    log "Server is in UTC. Backup scheduled at 01:00 UTC (04:00 MSK)."
else
    BACKUP_HOUR=4
    log "Server is in MSK/Local. Backup scheduled at 04:00 local time."
fi

# 4. Формируем команды с перенаправлением логов в /var/log/
BACKUP_CMD="python3 ${SCRIPT_DIR}/backup.py --password '${ZIP_PASSWORD}' --token '${YANDEX_OAUTH_TOKEN}' >> /var/log/wk-backup.log 2>&1"
RENEW_CMD="${SCRIPT_DIR}/renew-cert.sh wiki.fateev.moscow >> /var/log/wk-renew-cert.log 2>&1"

# Строки для crontab с уникальными ID-метками
BACKUP_CRON_LINE="0 ${BACKUP_HOUR} * * * ${BACKUP_CMD} # ID:WK_BACKUP_SCRIPT"
RENEW_CRON_LINE="0 3 1 */3 * ${RENEW_CMD} # ID:WK_RENEW_CERT_SCRIPT"

# 5. Обновляем crontab
CURRENT_CRON=$(sudo crontab -l 2>/dev/null || echo "")
NEW_CRON=$(echo "$CURRENT_CRON" | grep -v "# ID:WK_BACKUP_SCRIPT" | grep -v "# ID:WK_RENEW_CERT_SCRIPT" || true)
NEW_CRON=$(printf "%s\n%s\n%s" "$NEW_CRON" "$BACKUP_CRON_LINE" "$RENEW_CRON_LINE" | grep -v '^$')

#echo "$NEW_CRON"
echo "$NEW_CRON" | sudo crontab -
log "Cron jobs successfully updated/registered!"
