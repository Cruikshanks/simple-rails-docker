# frozen_string_literal: true

class AddressController < ApplicationController

  def show
    @message = "Search for a postcode"
  end

  def create
    postcode = params[:postcode]
    render json: DefraRuby::Address::EaAddressFacadeV1Service.run(postcode)
  end
end
