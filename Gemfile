# frozen_string_literal: true

source "https://rubygems.org"
ruby "2.4.2"

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem "rails", "~> 4.2.11"
# Use postgresql as the database for Active Record
gem "pg", "~> 0.18.4"
# Use SCSS for stylesheets
gem "sass-rails", "~> 5.0"
# Use Uglifier as compressor for JavaScript assets
gem "uglifier", ">= 1.3.0"
# Use CoffeeScript for .coffee assets and views
gem "coffee-rails", "~> 4.1.0"
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem "jquery-rails"
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem "turbolinks"
# bundle exec rake doc:rails generates the API under doc/api.
gem "sdoc", "~> 0.4.0", group: :doc

# Use Whenever to manage cron tasks
gem "whenever", "~> 0.10.0"

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Used to handle requests to the address lookup web service used (currently
# EA Address Facade v1)
gem "defra_ruby_address"

group :development, :test do
  # Load env vars from a .env file. Critical to managing multiple projects
  # in local and CI environments
  gem "dotenv-rails"
  # Call 'binding.pry' anywhere in the code to stop execution and get a debugger console
  gem "pry-byebug"
  # Project uses RSpec as its test framework
  gem "rspec-rails", "~> 3.8"
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem "web-console", "~> 2.0"

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem "spring"
end

group :test do
  # Database Cleaner is a set of strategies for cleaning your database in Ruby.
  gem "database_cleaner"
  # Generates a test coverage report on every `bundle exec rspec` call. We use
  # the output to feed CodeClimate's stats and analysis
  gem "simplecov", "~> 0.17.1", require: false
end

group :production do
  # Use Puma as the app server, but only when running in production as we find
  # local development easier using webrick
  gem "puma"
end
