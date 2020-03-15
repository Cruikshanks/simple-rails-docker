# frozen_string_literal: true

require "defra_ruby/address"

DefraRuby::Address.configure do |config|
  config.host = "http://address:9002"
end
