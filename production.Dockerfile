FROM ruby:2.4.2

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

# Add a script to be executed every time the container starts.
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh

# Control the version of bundler used in the container
RUN gem install bundler -v 1.17.3 \
 && bundle config force_ruby_platform true

WORKDIR /usr/src/app

# Set rails environment variables
ENV RAILS_ENV production

COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

COPY . .

RUN bundle exec rake assets:precompile

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

# This command will always be run, regardless of what is passed in on the cmd
# line when docker run is called
ENTRYPOINT ["entrypoint.sh"]

# This is the default cmd that will be run if an alternate is not passed in at
# the command line. In this container what actually happens is that the
# entrypoint.sh script is run, and it then ensures whatever is set for CMD
# (whether this default or what is set in docker run) is called afterwards
CMD ["bundle", "exec", "puma"]
