# frozen_string_literal: true

require "defra_ruby/address"

DefraRuby::Address.configure do |config|
  config.host = ENV["ADDRESS_LOOKUP_URL"]
end
