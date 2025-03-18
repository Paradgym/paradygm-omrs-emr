# syntax=docker/dockerfile:1.3
FROM nginx:1.25-alpine

# Set environment variables
ENV FRAME_ANCESTORS ""

# Install SSL generation tools
RUN apk add --no-cache openssl

# Create directory for SSL certificates
RUN mkdir -p /etc/nginx/ssl

# Generate self-signed certificates with stronger security
RUN openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout /etc/nginx/ssl/nginx-selfsigned.key \
    -out /etc/nginx/ssl/nginx-selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" && \
    openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048 && \
    chmod 600 /etc/nginx/ssl/nginx-selfsigned.key

# Copy Nginx configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf.template /etc/nginx/templates/

# Expose HTTP and HTTPS ports
EXPOSE 80 443