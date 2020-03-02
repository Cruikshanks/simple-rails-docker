# frozen_string_literal: true

Rails.application.routes.draw do
  get "/welcome",
      to: "welcome#show",
      as: "welcome"

  get "/email",
      to: "email#show",
      as: "email"

  post "/email",
       to: "email#create",
       as: "email_send"

  root "welcome#show"

  get "/healthcheck",
      to: proc { [200, {}, ["OK"]] },
      as: "healthcheck"
end
