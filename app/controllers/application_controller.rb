class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  after_action :set_response_language_header

  def set_response_language_header
    response.headers["Content-Language"] = I18n.locale.to_s
  end
end
