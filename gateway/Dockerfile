# syntax=docker/dockerfile:1.3
FROM nginx:1.25-alpine

# Set environment variables
ENV FRAME_ANCESTORS ""

# Install SSL generation tools
RUN apk add --no-cache openssl

# Create directory for SSL certificates
RUN mkdir -p /etc/nginx/ssl

# Copy Nginx configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf.template /etc/nginx/templates/

# Expose HTTP and HTTPS ports
EXPOSE 80 443