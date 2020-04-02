# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Welcome page", type: :request do
  describe "/ (root)" do
    let(:request_path) { "/" }

    it "returns a 200 response" do
      get request_path
      expect(response).to have_http_status(200)
    end
  end
end
