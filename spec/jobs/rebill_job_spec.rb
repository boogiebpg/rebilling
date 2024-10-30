# frozen_string_literal: true

require "rails_helper"

RSpec.describe RebillJob, type: :job do
  let(:subscription_id) { "test_subscription" }
  let(:amount) { 50.0 }
  let(:scheduled_count) { 1 }
  let(:rebilling_service) { instance_double(RebillingService) }

  describe "#perform" do
    it "calls the RebillingService with the correct parameters" do
      allow(RebillingService).to receive(:new).with(subscription_id, amount,
                                                    scheduled_count).and_return(rebilling_service)
      allow(rebilling_service).to receive(:call!)

      described_class.perform_now(subscription_id, amount, scheduled_count)

      expect(RebillingService).to have_received(:new).with(subscription_id, amount, scheduled_count)
      expect(rebilling_service).to have_received(:call!)
    end

    it "handles exceptions raised by the RebillingService" do
      allow(RebillingService).to receive(:new).with(subscription_id, amount,
                                                    scheduled_count).and_return(rebilling_service)
      allow(rebilling_service).to receive(:call!).and_raise(RebillingService::PaymentFailedError)

      expect do
        described_class.perform_now(subscription_id, amount, scheduled_count)
      end.to raise_error(RebillingService::PaymentFailedError)
    end
  end
end
