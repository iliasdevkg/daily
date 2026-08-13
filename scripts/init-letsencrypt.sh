#!/usr/bin/env bash
# One-time setup: issues real Let's Encrypt certs for the three domains
# nginx/nginx.conf expects, using certbot's webroot method against nginx
# itself. Run once before the first `docker compose -f
# docker-compose.prod.yml up`, from the repo root, on the actual production
# host (DNS for all three domains must already point here).
set -euo pipefail

DOMAINS=(api.daily.kg admin.daily.kg daily.kg www.daily.kg)
EMAIL="${LETSENCRYPT_EMAIL:?Set LETSENCRYPT_EMAIL first, e.g. LETSENCRYPT_EMAIL=you@example.com ./scripts/init-letsencrypt.sh}"
DATA_PATH="./nginx/certbot"

mkdir -p "$DATA_PATH/conf" "$DATA_PATH/www"

# Self-signed placeholder so nginx has *something* to load and can start —
# it's replaced by the real cert below within the same run.
if [ ! -e "$DATA_PATH/conf/live/api.daily.kg/fullchain.pem" ]; then
  echo "== Dummy certificate жасалууда ==" >&2
  for domain in "${DOMAINS[@]}"; do
    path="$DATA_PATH/conf/live/$domain"
    mkdir -p "$path"
    docker run --rm -v "$(pwd)/$DATA_PATH/conf:/etc/letsencrypt" certbot/certbot \
      openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
      -keyout "/etc/letsencrypt/live/$domain/privkey.pem" \
      -out "/etc/letsencrypt/live/$domain/fullchain.pem" \
      -subj "/CN=$domain" >/dev/null 2>&1
  done
fi

echo "== nginx dummy сертификат менен баштатылууда ==" >&2
docker compose -f docker-compose.prod.yml up -d nginx

echo "== Dummy сертификаттар алынып салынууда ==" >&2
rm -rf "$DATA_PATH/conf/live" "$DATA_PATH/conf/archive" "$DATA_PATH/conf/renewal"

echo "== Чыныгы Let's Encrypt сертификаттары суралууда ==" >&2
DOMAIN_ARGS=""
for domain in "${DOMAINS[@]}"; do DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"; done

docker run --rm \
  -v "$(pwd)/$DATA_PATH/conf:/etc/letsencrypt" \
  -v "$(pwd)/$DATA_PATH/www:/var/www/certbot" \
  certbot/certbot certonly --webroot -w /var/www/certbot \
  --email "$EMAIL" --agree-tos --no-eff-email $DOMAIN_ARGS

echo "== nginx кайра жүктөлүүдө (чыныгы сертификат менен) ==" >&2
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload

echo "Даяр. Сертификаттар 90 күндөн кийин мөөнөтү бүтөт — docker-compose.prod.yml'деги certbot контейнери аларды 12 сааттан бир текшерип автоматтык жаңылайт."
