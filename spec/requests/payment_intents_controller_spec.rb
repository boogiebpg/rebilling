# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentIntentsController, type: :request do
  describe "POST /paymentIntents/create" do
    let(:subscription_id) { "test_subscription" }
    let(:amount) { 100.0 }
    let(:params) { { subscription_id: subscription_id, amount: amount } }

    context "when the payment is successful" do
      before do
        allow_any_instance_of(RebillingService)
          .to receive(:call!)
          .and_return("Success. Charged amount: #{amount}.")
      end

      it "returns a success message and status 200" do
        post "/paymentIntents/create", params: params

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Success. Charged amount: #{amount}.")
      end
    end

    context "when the payment has insufficient funds" do
      before do
        allow_any_instance_of(RebillingService)
          .to receive(:call!)
          .and_return("Insufficient Funds.")
      end

      it "returns an insufficient funds message and status 200" do
        post "/paymentIntents/create", params: params

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Insufficient Funds.")
      end
    end

    context "when the payment fails" do
      before do
        allow_any_instance_of(RebillingService)
          .to receive(:call!)
          .and_raise(RebillingService::PaymentFailedError, "Failed payment")
      end

      it "returns an error message and status 422" do
        post "/paymentIntents/create", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Failed payment")
      end
    end

    context "when an unexpected payment status is returned" do
      before do
        allow_any_instance_of(RebillingService)
          .to receive(:call!)
          .and_raise(RebillingService::UnexpectedPaymentStatusError.new("unknown_status"))
      end

      it "returns an unexpected status error message and status 422" do
        post "/paymentIntents/create", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Received unexpected payment status: unknown_status")
      end
    end

    context "when invalid parameters are provided" do
      let(:invalid_params) { { subscription_id: nil, amount: nil } }

      it "returns a bad request error and status 400" do
        post "/paymentIntents/create", params: invalid_params

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include("Invalid parameters")
      end
    end
  end
end
