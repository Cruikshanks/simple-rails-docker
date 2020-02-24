# frozen_string_literal: true

class WelcomeController < ApplicationController

  def show
    @message = "A Rails and Docker demo project"
  end
end
