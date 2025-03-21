# syntax=docker/dockerfile:1.3
FROM nginx:1.25-alpine

# Set environment variables
ENV FRAME_ANCESTORS ""

# Copy Nginx configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf.template /etc/nginx/templates/

# Expose HTTP and HTTPS ports
EXPOSE 80 443