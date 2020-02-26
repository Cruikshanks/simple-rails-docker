FROM nginx:1.17.8-alpine

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

# A healthcheck for the container. When running periodically ping the host to
# confirm it can return a response in 3 seconds. In this case if we get 3 or
# more consecutive failures then the container will be flagged as unhealthy
# https://docs.docker.com/engine/reference/builder/#healthcheck
# https://stackoverflow.com/a/47722899
#
# `--quiet`   Turn off wget's output
# `--tries=1` Required because a non-HTTP 200 will cause wget to retry indefinitely
# `--spider`  Behave as a web spider, which means that it will not download the pages
# `|| exit 1` Healthcheck only expects a a 0 or 1 returned. So force all errors to return 1
HEALTHCHECK --interval=1m --timeout=3s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://{$SERVER_NAME} || exit 1

# Use the "exec" form of CMD so Nginx shuts down gracefully on SIGTERM
# (i.e. `docker stop`)
CMD [ "nginx", "-g", "daemon off;" ]
