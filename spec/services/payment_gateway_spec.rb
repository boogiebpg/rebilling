# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentGateway do
  describe ".create_payment_intent" do
    let(:amount) { 100.0 }
    let(:subscription_id) { "test_subscription" }

    it "returns one of the defined statuses" do
      response = PaymentGateway.create_payment_intent(amount, subscription_id)

      expect(%w[success insufficient_funds failed]).to include(response[:status])
    end
  end
end
