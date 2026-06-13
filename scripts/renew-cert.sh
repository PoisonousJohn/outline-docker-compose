#!/bin/bash
# Renews Let's Encrypt certificate and reloads nginx inside Docker.
# Usage: ./scripts/renew-cert.sh [domain]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$SCRIPT_DIR/config.sh" ]; then
    . "$SCRIPT_DIR/config.sh"
fi

DOMAIN="${1:-${CERTBOT_DOMAIN:-}}"
EMAIL="${2:-${CERTBOT_EMAIL:-}}"

if [ -z "$DOMAIN" ]; then
    echo "ERROR: domain not set. Pass it as argument or set CERTBOT_DOMAIN in config.sh" >&2
    exit 1
fi

if [ -z "$EMAIL" ]; then
    echo "ERROR: email not set. Set CERTBOT_EMAIL in config.sh" >&2
    exit 1
fi

CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
NGINX_CONFIG_DIR="${PROJECT_DIR}/config/nginx"
NGINX_CERT_DIR="${NGINX_CONFIG_DIR}/letsencrypt/certificates"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "Issuing/Renewing certificate for $DOMAIN"

if [ ! -f "/etc/letsencrypt/renewal/${DOMAIN}.conf" ]; then
    log "Renewal config not found. Executing initial certonly via webroot..."

    certbot certonly --webroot -w "$NGINX_CONFIG_DIR" -d "$DOMAIN" \
        --keep-until-expiring --non-interactive --agree-tos \
        --email "$EMAIL"
else
    log "Renewal config found. Executing standard renew..."
    certbot renew --cert-name "$DOMAIN" --quiet --no-random-sleep-on-renew
fi

log "Copying certs to Nginx config folder..."
mkdir -p "$NGINX_CERT_DIR"
cp "$CERT_DIR/fullchain.pem" "$NGINX_CERT_DIR/${DOMAIN}.crt"
cp "$CERT_DIR/privkey.pem"   "$NGINX_CERT_DIR/${DOMAIN}.key"
cp "$CERT_DIR/chain.pem"     "$NGINX_CERT_DIR/${DOMAIN}.issuer.crt"

chmod 644 "$NGINX_CERT_DIR/${DOMAIN}.crt"
chmod 644 "$NGINX_CERT_DIR/${DOMAIN}.issuer.crt"
chmod 600 "$NGINX_CERT_DIR/${DOMAIN}.key"

log "Reloading nginx container..."
cd "$PROJECT_DIR"
docker compose exec wk-nginx nginx -s reload

log "Done"
