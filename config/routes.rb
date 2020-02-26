# frozen_string_literal: true

Rails.application.routes.draw do
  get "/welcome",
      to: "welcome#show",
      as: "welcome"

  root "welcome#show"

  get "/healthcheck", to: proc { [200, {}, ["OK"]] }
end
