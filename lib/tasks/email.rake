# frozen_string_literal: true

namespace :email do
  desc "Send a test email to confirm setup is correct"
  task test: :environment do
    recipient = "canyouseeme@example.com"
    TestMailer.multipart_email(recipient, true).deliver_now
  end
end
