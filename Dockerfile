################################################################################
# Generate base ruby stage
#
# Use alpine version to help reduce size of image and improve security (less
# things installed from the get go)
FROM ruby:2.4.2-alpine3.7 AS rails_base

# Let folks know who created the image. You might see MAINTAINER <name> in older
# examples, but this instruction is now deprecated
LABEL maintainer="alan.cruikshanks@gmail.com"

# Set out working directory (no need to create it first)
WORKDIR /usr/src/app

# Install the dependencies we will always need at run time
RUN apk add --no-cache nodejs postgresql-client tzdata

# Create a system user to ensure when the final image is run as a container we
# don't run as root, which is considered a security violation
RUN addgroup -S appgroup && adduser -S app -G appgroup

# If set bundler will install all gems to this location. In our case we want a
# known location so we can easily copy the installed and compiled gems between
# images
ENV BUNDLE_PATH /usr/src/gems

# Control the version of bundler used in the container (we have had issues using
# bundle 2.0 with our old versions of ruby and rails)
RUN gem install bundler -v 1.17.3 \
 && bundle config force_ruby_platform true

################################################################################
# Stage used to install gems and pre-compile assets
#
FROM rails_base AS rails_builder

LABEL maintainer="alan.cruikshanks@gmail.com"

WORKDIR /usr/src/app

# Install just the things we need to be able to run `bundle install` and compile
# any gems with native extensions such as Nokogiri
#
# `--no-cache` Don't cache the index locally. Equivalent to `apk update` in the
#   beginning and `rm -rf /var/cache/apk/*` at the end
# `--virtual build-dependencies` Tag the installed packages as a group which can
#   then be used to quickly remove them when done with
RUN apk add --no-cache --virtual build-dependencies build-base ruby-dev postgresql-dev

# Install the gems
# Assuming we are in the root of the project copy the Gemfiles across. By just
# copying these we'll only cause this image to rebuild if the gemfiles have
# changed
COPY Gemfile Gemfile.lock ./
# We specifically don't use the `--without development test`. This is as a
# result of reading an article which recommended avoiding doing so. For the sake
# of a slightly larger image we have a much more reusable and cacheable builder
# stage.
# - `rm -rf /usr/src/gems/cache/*.gem` Remove the cache. If anything changes
#   Docker will rebuild the whole layer so a cache is pointless
# - `find /usr/src/gems/gems/ -name "*.c" -delete` This and the command that
#   follows removes any C files used to build the libraries
RUN bundle install \
 && rm -rf /usr/src/gems/cache/*.gem \
 && find /usr/src/gems/gems/ -name "*.c" -delete \
 && find /usr/src/gems/gems/ -name "*.o" -delete

# Pre-compile the assets
# We start by copying across just the code files we need to run
# `rake assets:precompile`.
COPY config/ ./config
COPY Rakefile .
# We then copy accross just the assets and public folders. Again like the gems,
# we only want to rebuild this image if an asset has changed not just because a
# code file has changed.
COPY app/assets ./app/assets
COPY public ./public

# Compile the assets in /public/assets
RUN bundle exec rake assets:precompile

# Uninstall those things we added just to be able to run `bundle install`
# `--no-cache` Same as `add` it stops the index being cached locally
# `build-dependencies` Virtual name given to a group of packages when installed
RUN apk del --no-cache build-dependencies

################################################################################
# Create development rails [app] (final stage)
#
FROM rails_base AS rails_development

LABEL maintainer="alan.cruikshanks@gmail.com"

WORKDIR /usr/src/app

# Copy the gems generated in the rails_builder stage from its image to this one
COPY --from=rails_builder /usr/src/gems /usr/src/gems

# Leaving as documentation as to why we don't do `COPY . .` in development.
#
# In the development build we want to provide an environment where development
# can take place but the user/developer does not have to install anything
# locally if that is the workflow they choose to use.
#
# Instead if you were to run this container you would be expected to bind mount
# a local folder to the container when it ran https://docs.docker.com/storage/bind-mounts/
#
# Because we intend to use Compose in most cases, this project's development
# docker-compose.yml (docker-compose.development.yml) handles setting up the
# bind mount.
#
# This means when the container is run, the current directory is shared with the
# running container, and means we can do things like editing files locally and
# see the changes in the running instance in the development container.
# COPY . .

# Set the rails environment variable
ENV RAILS_ENV development

# When the app is run in a container we need the logs to be written to STDOUT
# and not the default of log/production.log. The app doesn't really care about
# the value of the env var, simply that it exists. If it does the app will set
# its logger to use STDOUT.
ENV LOG_TO_STDOUT 1

# Specifiy listening port for the container
EXPOSE 3000

# Script that will ensure db:create and db:migrate is run before we attempt to
# run our app. This should ensure the container runs successfully the first
# time it's created, and everytime after that.
ENTRYPOINT [ "./entrypoint.sh" ]

# This is the default cmd that will be run if an alternate is not passed in at
# the command line.
# Use the "exec" form of CMD so rails shuts down gracefully on SIGTERM
# (i.e. `docker stop`)
CMD [ "bundle", "exec", "rails", "s", "-b", "0.0.0.0", "-p", "3000" ]

################################################################################
# Create test rails [app] (final stage)
#
FROM rails_base AS rails_test

LABEL maintainer="alan.cruikshanks@gmail.com"

WORKDIR /usr/src/app

# Copy the gems generated in the rails_builder stage from its image to this one
COPY --from=rails_builder /usr/src/gems /usr/src/gems

# Leaving as documentation as to why we don't do `COPY . .` in development.
#
# In the development build we want to provide an environment where development
# can take place but the user/developer does not have to install anything
# locally if that is the workflow they choose to use.
#
# Instead if you were to run this container you would be expected to bind mount
# a local folder to the container when it ran https://docs.docker.com/storage/bind-mounts/
#
# Because we intend to use Compose in most cases, this project's development
# docker-compose.yml (docker-compose.development.yml) handles setting up the
# bind mount.
#
# This means when the container is run, the current directory is shared with the
# running container, and means we can do things like editing files locally and
# see the changes in the running instance in the development container.
# COPY . .

# Set the rails environment variable
ENV RAILS_ENV test

# Don't log to STDOUT
# Unlike the other stages we don't want Rails logging to STDOUT when it does the
# output gets mixed up with Rspec's and makes it unreadble
# ENV LOG_TO_STDOUT 1

# This container is purely for running unit tests. So we have no need to send
# requests to the app
# EXPOSE 3000

# Script that will ensure db:create and db:migrate is run before we attempt to
# run our app. This should ensure the container runs successfully the first
# time it's created, and everytime after that.
ENTRYPOINT [ "./entrypoint.sh" ]

# This is the default cmd that will be run if an alternate is not passed in at
# the command line.
# Use the "exec" form of CMD so rspec shuts down gracefully on SIGTERM
# (i.e. `docker stop`)
CMD [ "bundle", "exec", "rspec" ]

################################################################################
# Create production rails [app] (final stage)
#
FROM rails_base AS rails_production

LABEL maintainer="alan.cruikshanks@gmail.com"

WORKDIR /usr/src/app

# Assuming we are in the root of the project, copy all the code (excluding
# whatever is in .dockerignore) into the current directory (which is WORKDIR)
COPY . .

# Remove app code we don't actually need or when the app is run in production,
# plus the public folder as we're grabbing that out of rails_builder
RUN rm -rf spec test app/assets vendor/assets tmp/cache public

# Copy the gems generated in the rails_builder stage from its image to this one
COPY --from=rails_builder /usr/src/gems /usr/src/gems
# Copy the assets in the rails_builder stage from its image to this one
COPY --from=rails_builder /usr/src/app/public ./public

# Set the rails environment variable
ENV RAILS_ENV production

# When the app is run in a container we need the logs to be written to STDOUT
# and not the default of log/production.log. The app doesn't really care about
# the value of the env var, simply that it exists. If it does the app will set
# its logger to use STDOUT.
ENV LOG_TO_STDOUT 1

# Specifiy listening port for the container
EXPOSE 3000

# Set the user to app instead of root. From this point on all commands will
# be run as the app user, even when you `docker exec` into the container
USER app

# This is the default cmd that will be run if an alternate is not passed in at
# the command line.
# Use the "exec" form of CMD so puma shuts down gracefully on SIGTERM
# (i.e. `docker stop`)
CMD [ "bundle", "exec", "puma" ]

################################################################################
# Create rails [admin] (final stage)
#
# The admin image is only intended to be used for running cron jobs and
# performing one off tasks such as data migrations. It should not be scaled and
# only one instance should ever be running.
#
FROM rails_base AS rails_admin

LABEL maintainer="alan.cruikshanks@gmail.com"

# Adding this package appears to be needed to interact with crontab. Prior to
# adding this line any calls to crontab e.g. `crontab -l` returned the error
# `crontab: must be suid to work properly`
# A stackoverflow post (https://superuser.com/a/1067180) gave adding this as the
# solution. For reference SUID means
#
# > SUID (Set owner User ID up on execution) is a special type of file
#   permissions given to a file. Normally in Linux/Unix when a program runs, it
#   inherit’s access permissions from the logged in user. SUID is defined as
#   giving temporary permissions to a user to run a program/file with the
#   permissions of the file owner rather that the user who runs it.
# https://www.linuxnix.com/suid-set-suid-linuxunix/
#
# Essentially with crontab we need to access files in /etc which are not
# accessible to 'normal' users. So crontab sets SUID on its command files to
# allow a normal user to run them as if they were root. It being Alpine though
# we have to add the package to support SUID functionality first
RUN apk add --no-cache busybox-suid

# Install supercronic https://github.com/aptible/supercronic/
# Supercronic is a crontab-compatible job runner, designed specifically to run
# in containers. We believe the ideal is actually cron or something like it is
# used on the host where the container is running to call jobs according to a
# schedule e.g. `docker exec simple-rails-docker_admin_1 bundle exec rake myjob`
# We currently use the whenever gem to generate our crontab file.
#
# So whilst we familirise ourselves with Docker, and also so we retain some
# control over how things are done we want to replicate what happens at the
# moment. This means getting cron working in a Docker container. Cron does not
# like working in a Docker container!
#
# Our main issue appeared to be a need to run as the root user which we
# have to avoid. Also behaviour such as excluding existing env vars from the
# running context. A useful security feature on the host, but a pain in a Docker
# container. Check https://github.com/aptible/supercronic/#why-supercronic for
# more reasons. But iin summary, we needed an alternative and supercronic fits
# the bill.
#
# Installation steps are as follows
# - download pre-compiled binary from the site and save as
#   /usr/local/bin/supercronic
# - confirm the checksum (Note, the double space between values is intended and
#   required!)
# - make the file executable
# These steps differ from the instructions supercronic provide, only because
# they rely on curl being installed. Alpine only has wget, and as we have to
# re-write the instructions to cater for that, we also chose to simplify things
# further.
RUN wget -q https://github.com/aptible/supercronic/releases/download/v0.1.9/supercronic-linux-amd64 -O /usr/local/bin/supercronic \
 && echo "5ddf8ea26b56d4a7ff6faecdd8966610d5cb9d85  /usr/local/bin/supercronic" | sha1sum -c - \
 && chmod +x /usr/local/bin/supercronic

WORKDIR /usr/src/app

# Assuming we are in the root of the project, copy all the code (excluding
# whatever is in .dockerignore) into the current directory (which is WORKDIR)
COPY . .

# Remove app code we don't actually need or when the app is run in production,
# plus the public folder as we're grabbing that out of rails_builder
RUN rm -rf spec test app/assets vendor/assets tmp/cache public

# Copy the gems generated in the rails_builder stage from its image to this one
COPY --from=rails_builder /usr/src/gems /usr/src/gems
# Copy the assets in the rails_builder stage from its image to this one
COPY --from=rails_builder /usr/src/app/public ./public

# Set the rails environment variable
ENV RAILS_ENV production

# When the app is run in a container we need the logs to be written to STDOUT
# and not the default of log/production.log. The app doesn't really care about
# the value of the env var, simply that it exists. If it does the app will set
# its logger to use STDOUT.
ENV LOG_TO_STDOUT 1

# Set the rails port variable. We don't expect to start the rails server but
# just in case ensure it doesn't get confused as an 'app'
ENV RAILS_PORT 4000

# Generate the crontab file. This contains instructions for the cron(8) daemon
# in the following simplified manner: "run this command at this time on this
# date". The only difference is we use supercronic rather than cron.
# We must call this command before we switch to the rails user in order to have
# write permissions to create the file
RUN bundle exec whenever > crontab

# Set the user to app instead of root. From this point on all commands will
# be run as the app user, even when you `docker exec` into the container
USER app

# This is the default cmd that will be run if an alternate is not passed in at
# the command line.
# Start supercronic passing in our crontab generated by whenever during the
# build
# Use the "exec" form of CMD so supercronic shuts down gracefully on SIGTERM
# (i.e. `docker stop`)
CMD [ "/usr/local/bin/supercronic", "crontab" ]

################################################################################
# Create production nginx [web] (final stage)
#
FROM nginx:1.17.8-alpine AS nginx

# Let folks know who created the image. You might see MAINTAINER <name> in older
# examples, but this instruction is now deprecated
LABEL maintainer="alan.cruikshanks@gmail.com"

# Set our working directory inside the image
WORKDIR /usr/src/app

# Copy the app assets in the rails_builder stage from its image to this one
COPY --from=rails_builder /usr/src/app/public ./public

# Copy our Nginx config template
COPY nginx.conf /tmp/docker.nginx

# Like an env var, but used when building the image rather than when running
# the container. So this would need to be in the shell, provided on the cmd line
# or as in our case via the docker-compose file
ARG SERVER_NAME

# Substitute variable references in the Nginx config template for real values
# from the environment then put the final config in its proper place
RUN envsubst '$SERVER_NAME' < /tmp/docker.nginx > /etc/nginx/conf.d/default.conf

# In order to run Nginx as a non-root user you need to ensure it has ownership
# of everthing in our working directory (where we have copied our assets) plus
# a few other key files used by it
# https://www.rockyourcode.com/run-docker-nginx-as-non-root-user/
RUN touch /var/run/nginx.pid && \
  chown -R nginx:nginx . && chmod -R 755 . && \
  chown -R nginx:nginx /var/run/nginx.pid && \
  chown -R nginx:nginx /var/cache/nginx && \
  chown -R nginx:nginx /var/log/nginx && \
  chown -R nginx:nginx /etc/nginx/conf.d

# You can't have nginx listening on a port below 1024 because only the root user
# can access them. That's why we listen on port 8080. There is nothing to stop
# us forwarding port 80 on the host though to port 8080, so we'll still be able
# to request our app at http://localhost
EXPOSE 8080

# Set the user to nginx instead of root. From this point on all commands will
# be run as the app user, even when you `docker exec` into the container.
# The official Nginx image creates an nginx user, hence we haven't needed to
# create one in our Dockerfile
#
# NOTE. This will lead to a warning in the Docker output
#
#   2020/04/18 23:32:28 [warn] 1#1: the "user" directive makes sense only if the master process runs with super-user privileges, ignored in /etc/nginx/nginx.conf:2
#
# This is fine. We could remove it by retaining our own version of the
# nginx.conf file, removing the `user  nginx;` line, and then copying that
# across. But it seems pointless to maintain a copy of what is a copy of default
# file Nginx provides with just one line removed in order to avoid a single
# warning
USER nginx

# Use the "exec" form of CMD so Nginx shuts down gracefully on SIGTERM
# (i.e. `docker stop`)
CMD [ "nginx", "-g", "daemon off;" ]

################################################################################
# Create production address-lookup [address] (final stage)
#
FROM openjdk:8-alpine AS address

# Let folks know who created the image. You might see MAINTAINER <name> in older
# examples, but this instruction is now deprecated
LABEL maintainer="alan.cruikshanks@gmail.com"

# Set our working directory inside the image
WORKDIR /usr/src/app

# Create a system user to ensure when the final image is run as a container we
# don't run as root, which is considered a security violation
RUN addgroup -S appgroup && adduser -S app -G appgroup

# Copy the app code in the rails_builder stage from its image to this one
COPY ./abf .

# Addressbase Facade is built using Dropwizard which uses a normal port and an
# admin port for communication
EXPOSE 9002 9003

# Set the user to app instead of root. From this point on all commands will
# be run as the app user, even when you `docker exec` into the container
USER app

# Call our shell script which is responsible for creating a config file that
# contains the actual OS Places API key (/tmp/config.json). Unfortunately the
# Addressbase Facade is not setup to use environment variables as a means to
# provide config. We could have done this as part of the build using an ARG but
# that would mean the API key would be saved into the image, which is a security
# issue. So the solution we came up with is to use a shell script that is always
# run (because we use ENTRYPOINT) to generate a new config file using
# /usr/src/app/config.json as the template, and updating it with the actual API
# key.
#
# Also because we don't want to run as the root user (another best practise) so
# we are not able to update the existing file. Hence the script generates a new
# file in /tmp/config.json which we then reference in our CMD below
ENTRYPOINT [ "./entrypoint.sh" ]

# Use the "exec" form of CMD so the app shuts down gracefully on SIGTERM
# (i.e. `docker stop`)
CMD [ "java", "-jar", "target/ea-addressfacade-0.1.jar", "server", "/tmp/config.json" ]
