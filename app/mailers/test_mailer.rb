# frozen_string_literal: true

class TestMailer < ActionMailer::Base

  FROM_ADDRESS = "simple-rails-docker@example.com"

  def multipart_email(recipient, add_logo = false)
    add_logo_attachment if add_logo

    mail(
      to: recipient,
      from: FROM_ADDRESS,
      subject: "Multi-part email"
    ) do |format|
      format.html { render html: "<h1>This is the html version of an email</h1>".html_safe }
      format.text { render plain: "This is the text version of an email" }
    end
  end

  def html_email(recipient, add_logo = false)
    add_logo_attachment if add_logo

    mail(
      to: recipient,
      from: FROM_ADDRESS,
      subject: "HTML email"
    ) do |format|
      format.html { render html: "<h1>This is the html version of an email</h1>".html_safe }
    end
  end

  def text_email(recipient, add_logo = false)
    add_logo_attachment if add_logo

    mail(
      to: recipient,
      from: FROM_ADDRESS,
      subject: "Text email"
    ) do |format|
      format.text { render plain: "This is the text version of an email" }
    end
  end

  private

  def add_logo_attachment
    path = "/lib/assets/email-logo.png"

    full_path = File.join(Rails.root, path)

    attachments["email-logo.png"] = {
      data: File.read(full_path),
      mime_type: "image/png"
    }
  end
end
