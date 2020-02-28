################################################################################
# Generate ruby base image
#
# Use alpine version to help reduce size of image and improve security (less
# things installed from the get go)
FROM ruby:2.4.2-alpine3.7 AS ruby_base

# Let folks know who created the image. You might see MAINTAINER <name> in older
# examples, but this instruction is now deprecated
LABEL maintainer="alan.cruikshanks@gmail.com"

# Set out working directory (no need to create it first)
WORKDIR /usr/src/app

# Install time zone information and nodejs. These are needed both when compiling
# assets and running the rails
RUN apk add --no-cache nodejs tzdata

# If set bundler will install all gems to this location. In our case we want a
# known location so we can easily copy the installed and compiled gems between
# images
ENV BUNDLE_PATH /usr/src/gems

# Control the version of bundler used in the container (we have had issues using
# bundle 2.0 with our old versions of ruby and rails)
RUN gem install bundler -v 1.17.3 \
 && bundle config force_ruby_platform true

################################################################################
# Generate rails base image
#
# Use alpine version to help reduce size of image and improve security (less
# things installed from the get go)
FROM ruby_base AS rails_base

LABEL maintainer="alan.cruikshanks@gmail.com"

# Install the dependencies we will always need at run time
RUN apk add --no-cache nodejs postgresql-client

# Create a system user to ensure when the final image is run as a container we
# don't run as root, which is considered a security violation
RUN addgroup -S railsgroup && adduser -S rails -G railsgroup

################################################################################
# Create ruby builder image
#
# This creates an image that includes the build dependencies needed when
# installing gems with native extensions. Use this for images where you need
# to run a `bundle install` for example
FROM ruby_base AS ruby_builder

LABEL maintainer="alan.cruikshanks@gmail.com"

# Install just the things we need to be able to run `bundle install` and compile
# any gems with native extensions such as Nokogiri
#
# `--no-cache` Don't cache the index locally. Equivalent to `apk update` in the
#   beginning and `rm -rf /var/cache/apk/*` at the end
# `--virtual build-dependencies` Tag the installed packages as a group which can
#   then be used to quickly remove them when done with
RUN apk add --no-cache --virtual build-dependencies build-base ruby-dev postgresql-dev

################################################################################
# Create rails builder image
#
# This creates an image where the work of generating and installing a projects
# gems takes place, plus pre-compiling the assets
FROM ruby_builder AS rails_builder

LABEL maintainer="alan.cruikshanks@gmail.com"

WORKDIR /usr/src/app

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
# Create final production version
#
FROM rails_base AS rails_production

LABEL maintainer="alan.cruikshanks@gmail.com"

WORKDIR /usr/src/app

# Assuming we are in the root of the project, copy all the code (excluding
# whatever is in .dockerignore) into the current directory (which is WORKDIR)
COPY . .

# Remove app code we don't actually need or when the app is run in production,
# plus the public folder as we're grabbing that out of rails_builder
RUN rm -rf spec test app/assets vendor/assets lib/assets tmp/cache public

# Copy the gems generated in the rails_builder stage from its image to this one
COPY --from=rails_builder /usr/src/gems /usr/src/gems
# Copy the assets in the rails_builder stage from its image to this one
COPY --from=rails_builder /usr/src/app/public ./public

# Set the rails environment variable
ENV RAILS_ENV production

# Specify listening port for the container
EXPOSE 3000

# Set the user to rails instead of root. From this point on all commands will
# be run as the rails user, even when you `docker exec` into the container
USER rails

# This is the default cmd that will be run if an alternate is not passed in at
# the command line.
CMD ["bundle", "exec", "puma"]

################################################################################
# Create nginx
#
FROM nginx:1.17.8-alpine AS nginx

# Let folks know who created the image. You might see MAINTAINER <name> in older
# examples, but this instruction is now deprecated
LABEL maintainer="alan.cruikshanks@gmail.com"

# Set our working directory inside the image
WORKDIR /usr/src/app

# Copy the app code in the rails_builder stage from its image to this one
COPY --from=rails_builder /usr/src/app/public ./public

# Copy Nginx config template
COPY nginx.conf /tmp/docker.nginx

ARG SERVER_NAME

# Substitute variable references in the Nginx config template for real values
# from the environment then put the final config in its proper place
RUN envsubst '$SERVER_NAME' < /tmp/docker.nginx > /etc/nginx/conf.d/default.conf

# Specify listening port for the container
EXPOSE 80

# Use the "exec" form of CMD so Nginx shuts down gracefully on SIGTERM
# (i.e. `docker stop`)
CMD [ "nginx", "-g", "daemon off;" ]

################################################################################
# Create mailcatcher
#
FROM ruby_builder AS mailcatcher

LABEL maintainer="alan.cruikshanks@gmail.com"

# Install the sqlite dependency mailcatcher needs
RUN apk add --no-cache sqlite-dev

# Install the mailcatcher gem https://github.com/sj26/mailcatcher
RUN gem install mailcatcher

# Uninstall those things we added just to be able to run `bundle install`
# `--no-cache` Same as `add` it stops the index being cached locally
# `build-dependencies` Virtual name given to a group of packages when installed
RUN apk del --no-cache build-dependencies

# Specify listening port for the container
EXPOSE 1080

# This is the default cmd that will be run if an alternate is not passed in at
# the command line.
CMD ["mailcatcher", "--http-ip", "0.0.0.0"]
