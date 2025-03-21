#!/bin/sh
set -e

# if we are using the $IMPORTMAP_URL environment variable, we have to make this useful,
# so we change "importmap.json" into "$IMPORTMAP_URL" allowing it to be changed by envsubst
if [ -n "${IMPORTMAP_URL}" ]; then
  if [ -n "$SPA_PATH" ]; then
    [ -f "/usr/share/nginx/html/index.html"  ] && \
      sed -i -e 's/\("|''\)$SPA_PATH\/importmap.json\("|''\)/\1$IMPORTMAP_URL\1/g' "/usr/share/nginx/html/index.html"

    [ -f "/usr/share/nginx/html/service-worker.js" ] && \
      sed -i -e 's/\("|''\)$SPA_PATH\/importmap.json\("|''\)/\1$IMPORTMAP_URL\1/g' "/usr/share/nginx/html/service-worker.js"
  else
    [ -f "/usr/share/nginx/html/index.html"  ] && \
      sed -i -e 's/\("|''\)importmap.json\("|''\)/\1$IMPORTMAP_URL\1/g' "/usr/share/nginx/html/index.html"

    [ -f "/usr/share/nginx/html/service-worker.js" ] && \
      sed -i -e 's/\("|''\)importmap.json\("|''\)/\1$IMPORTMAP_URL\1/g' "/usr/share/nginx/html/service-worker.js"
  fi
fi

# setting the config urls to "" causes an error reported in the console, so if we aren't using
# the SPA_CONFIG_URLS, we remove it from the source, leaving config urls as []
if [ -z "$SPA_CONFIG_URLS" ]; then
  sed -i -e 's/"$SPA_CONFIG_URLS"//' "/usr/share/nginx/html/index.html"
# otherwise convert the URLs into a Javascript list
# we support two formats, a comma-separated list or a space separated list
else
  old_IFS="$IFS"
  if echo "$SPA_CONFIG_URLS" | grep , >/dev/null; then
    IFS=","
  fi

  CONFIG_URLS=
  for url in $SPA_CONFIG_URLS;
  do
    if [ -z "$CONFIG_URLS" ]; then
      CONFIG_URLS="\"${url}\""
    else
      CONFIG_URLS="$CONFIG_URLS,\"${url}\""
    fi
  done

  IFS="$old_IFS"
  export SPA_CONFIG_URLS=$CONFIG_URLS
  sed -i -e 's/"$SPA_CONFIG_URLS"/$SPA_CONFIG_URLS/' "/usr/share/nginx/html/index.html"
fi

SPA_DEFAULT_LOCALE=${SPA_DEFAULT_LOCALE:-en_GB}

# Substitute environment variables in the html file
# This allows us to override parts of the compiled file at runtime
if [ -f "/usr/share/nginx/html/index.html" ]; then
  envsubst '${IMPORTMAP_URL} ${SPA_PATH} ${API_URL} ${SPA_CONFIG_URLS} ${SPA_DEFAULT_LOCALE}' < "/usr/share/nginx/html/index.html" | sponge "/usr/share/nginx/html/index.html"
fi

if [ -f "/usr/share/nginx/html/service-worker.js" ]; then
  envsubst '${IMPORTMAP_URL} ${SPA_PATH} ${API_URL}' < "/usr/share/nginx/html/service-worker.js" | sponge "/usr/share/nginx/html/service-worker.js"
fi

# Replace the <title> in index.html if PAGE_TITLE is set
if [ -n "$PAGE_TITLE" ] && [ -f "/usr/share/nginx/html/index.html" ]; then
  sed -i -e "s|<title>.*</title>|<title>${PAGE_TITLE}</title>|g" "/usr/share/nginx/html/index.html"
fi

if [ ! -f /etc/nginx/ssl/fullchain.pem ] || [ ! -f /etc/nginx/ssl/privkey.pem ]; then
    mkdir -p /etc/nginx/ssl

    if [ ! -z "$DOMAIN" ]; then
        echo "Stopping Nginx to request Let's Encrypt certificate..."
        nginx -s stop

        echo "Requesting Let's Encrypt certificate for $DOMAIN..."
        certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL --domain $DOMAIN --keep-until-expiring

        echo "Restarting Nginx..."
        nginx

        # Link the certificates
        ln -sf /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/nginx/ssl/fullchain.pem
        ln -sf /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/nginx/ssl/privkey.pem
    fi
fi


if [ ! -z "$DOMAIN" ]; then
    export SSL_CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    export SSL_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
else
    export SSL_CERT="/etc/nginx/ssl/nginx-selfsigned.crt"
    export SSL_KEY="/etc/nginx/ssl/nginx-selfsigned.key"
fi

# Set up auto-renewal
if [ -n "$DOMAIN" ]; then
    echo "Setting up certificate auto-renewal..."
    while :; do
        certbot renew --quiet
        sleep 12h
    done &
fi

exec nginx -g "daemon off;"
