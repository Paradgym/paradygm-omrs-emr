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

# Check if certificates exist, if not, generate them
if [ ! -f /etc/nginx/ssl/fullchain.pem ] || [ ! -f /etc/nginx/ssl/privkey.pem ]; then
    # Check if we're in production mode with a domain
    if [ ! -z "$DOMAIN" ]; then
        echo "Requesting Let's Encrypt certificate for $DOMAIN..."
        
        # Request certificate
        certbot certonly --standalone \
            --non-interactive --agree-tos \
            --email $EMAIL \
            --domain $DOMAIN \
            --keep-until-expiring
            
        # Link the certificates
        ln -sf /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/nginx/ssl/fullchain.pem
        ln -sf /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/nginx/ssl/privkey.pem
    else
        echo "No domain specified, generating self-signed certificate..."
        openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
            -keyout /etc/nginx/ssl/privkey.pem \
            -out /etc/nginx/ssl/fullchain.pem \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" \
            -addext "subjectAltName = DNS:localhost,IP:127.0.0.1" \
            -addext "extendedKeyUsage = serverAuth"
        chmod 600 /etc/nginx/ssl/privkey.pem
    fi
fi

# Set up auto-renewal
if [ -n "$DOMAIN" ]; then
    echo "Setting up certificate auto-renewal..."
    exec watch -n 43200 "certbot renew --quiet"
fi

exec nginx -g "daemon off;"
