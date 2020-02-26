# Use alpine version to help reduce size of image and imrpove security (less
# things installed from the get go)
FROM ruby:2.4.2-alpine3.7

# Set the rails environment variable
ENV RAILS_ENV production

# Set out working directory (no need to create it first)
WORKDIR /usr/src/app

# Control the version of bundler used in the container (we have had issues using
# bundle 2.0 with our old versions of ruby and rails)
RUN gem install bundler -v 1.17.3 \
 && bundle config force_ruby_platform true

# Install the dependencies we will always need at run time
RUN apk add --no-cache nodejs postgresql-client tzdata

# Copy over just the Gemfiles as this is all we need for the bundle install
COPY Gemfile Gemfile.lock ./

# #Install and compile our gems
#
# This is done in 3 stages to decrease the size of the image as much as
# possible. We came across this article on how to reduce your docker image size
# https://www.sandtable.com/reduce-docker-image-sizes-using-alpine/
#
# The key thing it and others push is to use a FROM image based on Alpine. After
# that it and the Rails examples we found followed the same process
#
# - install packages needed to build gems
# - install the gems
# - uninstall the packages
#
# E.g. https://gist.github.com/mzaidannas/ee6b6b9bdb795816d4c2006a37d45dde
#
# However a commentator pointed out that if the you do the apk add and apk del
# in separate run commands, you'll still get a layer with all the dependencies
# installed. And as the final image is essentially a combination of these
# layers you will see no benefit because layers are only additive.
#
# To confirm this we first created a build based on alpine with apk add
# build-deps, bundle install and the apkl del build-deps done separately. The
# final image was 410MB.
#
# We then performed all 3 in a single RUN (as below) and that final image was
# 239MB.
#
# In the following comments we go into more detail about each step.
#
# ## Add build dependencies
#
# Install just the things we need to be able to run `bundle install` and compile
# any gems with native extensions such as Nokogiri
#
# --no-cache Don't cache the index locally. Equivalent to `apk update` in the
#   beginning and `rm -rf /var/cache/apk/*` at the end
# --virtual build-dependencies Tag the installed packages as a group which can
#   then be used to quickly remove them when done with
#
# ## Install gems
#
# Install the gems we depend on. Some will have native extensions and need to be
# compiled hence the need to install build dependencies first
#
# --without development test Don't bother to install any gems listed in the
#   development and test groups
#
# ## Remove build dependencies
#
# Uninstall those things we added just to be able to run `bundle install`
#
# --no-cache Same as `add` it stops the index being cached locally
# build-dependencies Virtual name given to a group of packages when installed
#
RUN apk add --no-cache --virtual build-dependencies build-base ruby-dev postgresql-dev \
  && bundle install --without development test \
  && apk del --no-cache build-dependencies

# Assuming we are in the root of the project, copy all the code (excluding
# whatever is in .dockerignore) into the current directory (which is WORKDIR)
COPY . .

# Generate our assets
RUN bundle exec rake assets:precompile

# Specifiy listening port for the container
EXPOSE 3000

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
  CMD ["wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/healthcheck", "|| exit 1"]

# This is the default cmd that will be run if an alternate is not passed in at
# the command line. In this container what actually happens is that the
# entrypoint.sh script is run, and it then ensures whatever is set for CMD
# (whether this default or what is set in docker run) is called afterwards
CMD ["bundle", "exec", "puma"]
