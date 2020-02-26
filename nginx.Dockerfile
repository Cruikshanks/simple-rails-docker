FROM nginx:1.17.8

# Set our working directory inside the image
WORKDIR /usr/src/app

# Copy over static assets
COPY public public/

# Copy Nginx config template
COPY nginx.conf /tmp/docker.nginx

ARG SERVER_NAME

# Substitute variable references in the Nginx config template for real values
# from the environment then put the final config in its proper place
RUN envsubst '$SERVER_NAME' < /tmp/docker.nginx > /etc/nginx/conf.d/default.conf

EXPOSE 80

# Use the "exec" form of CMD so Nginx shuts down gracefully on SIGTERM
# (i.e. `docker stop`)
CMD [ "nginx", "-g", "daemon off;" ]
