#!/bin/bash
set -e

DOMAIN="${DOMAIN}"
EMAIL="${EMAIL_HOST_USER}"
WORKDIR="${GITHUB_WORKSPACE:-$(pwd)}"
CERT_FILE="$WORKDIR/data/certbot/conf/live/$DOMAIN/fullchain.pem"

needs_cert=true

if [ -f "$CERT_FILE" ]; then
    ISSUER=$(openssl x509 -in "$CERT_FILE" -noout -issuer 2>/dev/null)
    if echo "$ISSUER" | grep -qi "let.s encrypt\|letsencrypt"; then
        echo "Valid Let's Encrypt cert already exists for $DOMAIN. Skipping issuance."
        needs_cert=false
    else
        echo "Cert exists but is not from Let's Encrypt. Removing and re-issuing..."
        sudo rm -rf "$WORKDIR/data/certbot/conf/live/$DOMAIN"
        sudo rm -rf "$WORKDIR/data/certbot/conf/archive/$DOMAIN" 2>/dev/null || true
        sudo rm -f "$WORKDIR/data/certbot/conf/renewal/$DOMAIN.conf" 2>/dev/null || true
    fi
fi

if [ "$needs_cert" = "true" ]; then
    echo "Issuing Let's Encrypt certificate for $DOMAIN..."
    docker run --rm \
        -v "$WORKDIR/data/certbot/conf:/etc/letsencrypt" \
        -v "$WORKDIR/data/certbot/www:/var/www/certbot" \
        certbot/certbot certonly \
        --webroot -w /var/www/certbot \
        -d "$DOMAIN" \
        --email "$EMAIL" \
        --agree-tos \
        --non-interactive
fi

echo "Reloading nginx..."
docker exec "${PROJECT_NAME}-frontend" nginx -s reload

echo "Ensuring certbot renewal service is running..."
docker compose -f "$WORKDIR/docker-compose.certbot.yml" up -d certbot
