# frozen_string_literal: true

# Config based on a mix of things taken from
# https://runnable.com/docker/rails/docker-configuration
# https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server
# https://www.digitalocean.com/community/tutorials/how-to-deploy-a-rails-app-with-puma-and-nginx-on-ubuntu-14-04

# HTTP interface
port 3000

# Do not daemonize the server into the background
daemonize false

# We only expect to use puma in production hence that's our default, but we take
# the value from an env var to remain flexible!
environment ENV["RAILS_ENV"] || "production"

# The minimum and maximum number of threads to use to answer requests.
# The default is "0, 16". Based on some reading it is suggested that you should
# not allow your maximum to exceed the size of your database connection pool.
# As we are using ActiveRecord, the default is 5.
# https://devcenter.heroku.com/articles/concurrency-and-database-connections
threads 1, 5
