FROM ruby:2.4.2

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

# Add a script to be executed every time the container starts.
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

# This command will always be run, regardless of what is passed in on the cmd
# line when docker run is called
ENTRYPOINT ["entrypoint.sh"]

# This is the default cmd that will be run if an alternate is not passed in at
# the command line. In this container what actually happens is that the
# entrypoint.sh script is run, and it then ensures whatever is set for CMD
# (whether this default or what is set in docker run) is called afterwards
CMD ["rails", "server", "-b", "0.0.0.0"]
