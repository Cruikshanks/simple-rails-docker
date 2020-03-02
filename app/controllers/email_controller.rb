# frozen_string_literal: true

class EmailController < ApplicationController

  def show
    @message = "Send a test email"
  end

  def create
    TestMailer.multipart_email(params[:recipient], true).deliver_now
    redirect_to("/")
  end
end
