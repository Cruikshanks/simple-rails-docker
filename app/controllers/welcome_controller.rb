# frozen_string_literal: true

class WelcomeController < ApplicationController

  def show
    data = { message: "Hello world" }

    render json: data.to_json
  end
end
