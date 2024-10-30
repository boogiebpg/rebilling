# frozen_string_literal: true

require "rails_helper"

RSpec.describe RebillingService do
  let(:subscription_id) { "test_subscription" }
  let(:initial_amount) { 100.0 }

  describe "#call!" do
    context "when the first attempt is successful" do
      it "charges the full amount successfully and does not reschedule rebilling" do
        allow(PaymentGateway).to receive(:create_payment_intent)
          .with(initial_amount, subscription_id)
          .and_return(status: "success")
        allow(RebillScheduler).to receive(:schedule_one_week)

        service = described_class.new(subscription_id, initial_amount)
        result = service.call!

        expect(result).to include("Success. Charged amount: #{initial_amount}.")
        expect(PaymentAttempt.count).to eq(1)
        expect(PaymentAttempt.first.status).to eq("success")
        expect(RebillScheduler).not_to have_received(:schedule_one_week)
      end
    end

    context "when initial attempt fails due to insufficient funds but later succeeds" do
      it "attempts multiple charges with decreasing amounts and then reschedule remaining amount" do
        allow(PaymentGateway).to receive(:create_payment_intent).and_return(
          { status: "insufficient_funds" },
          { status: "success" },
        )
        allow(RebillScheduler).to receive(:schedule_one_week)

        service = described_class.new(subscription_id, initial_amount)
        result = service.call!

        expect(result).to include("Success. Charged amount: 75.0.")
        expect(PaymentAttempt.count).to eq(2)
        expect(PaymentAttempt.first.status).to eq("insufficient_funds")
        expect(PaymentAttempt.second.status).to eq("success")
        expect(RebillScheduler).to have_received(:schedule_one_week).with(subscription_id, 25.0, 1)
      end
    end

    context "when all attempts return insufficient funds" do
      it "logs each attempt and schedules a rebill for the whole amount" do
        allow(PaymentGateway).to receive(:create_payment_intent)
          .and_return({ status: "insufficient_funds" })
        allow(RebillScheduler).to receive(:schedule_one_week)

        service = described_class.new(subscription_id, initial_amount)
        result = service.call!

        expect(result).to include("Insufficient Funds.")
        expect(PaymentAttempt.count).to eq(4)
        expect(PaymentAttempt.pluck(:status)).to all(eq("insufficient_funds"))
        expect(RebillScheduler).to have_received(:schedule_one_week).with(subscription_id, 100.0, 1)
      end
    end

    context "when a failed response is received" do
      it "raises a PaymentFailedError and does not schedule a rebill" do
        allow(PaymentGateway).to receive(:create_payment_intent)
          .and_return({ status: "failed" })
        allow(RebillScheduler).to receive(:schedule_one_week)

        service = described_class.new(subscription_id, initial_amount)

        expect { service.call! }.to raise_error(RebillingService::PaymentFailedError)
        expect(PaymentAttempt.count).to eq(1)
        expect(PaymentAttempt.first.status).to eq("failed")
        expect(RebillScheduler).not_to have_received(:schedule_one_week)
      end
    end

    context "when an unexpected status is returned" do
      it "raises an UnexpectedPaymentStatusError and does not schedule a rebill" do
        allow(PaymentGateway).to receive(:create_payment_intent)
          .and_return({ status: "unknown_status" })
        allow(RebillScheduler).to receive(:schedule_one_week)

        service = described_class.new(subscription_id, initial_amount)

        expect { service.call! }.to raise_error(RebillingService::UnexpectedPaymentStatusError, /unknown_status/)
        expect(PaymentAttempt.count).to eq(1)
        expect(PaymentAttempt.first.status).to eq("unknown_status")
        expect(RebillScheduler).not_to have_received(:schedule_one_week)
      end
    end

    context "when partial payments with rebilling attempts are needed" do
      it "charges the partial amount successfully after a reschedule and rescheule one more time" do
        allow(PaymentGateway).to receive(:create_payment_intent)
          .and_return({ status: "insufficient_funds" }, { status: "success" })
        allow(RebillScheduler).to receive(:schedule_one_week)

        service = described_class.new(subscription_id, initial_amount, 2)
        result = service.call!

        expect(result).to include("Success. Charged amount: 75.0.")
        expect(service.instance_variable_get(:@scheduled_count)).to eq(2)
        expect(PaymentAttempt.count).to eq(2)
        expect(PaymentAttempt.first.status).to eq("insufficient_funds")
        expect(PaymentAttempt.second.status).to eq("success")
        expect(RebillScheduler).to have_received(:schedule_one_week).with(subscription_id, 25.0, 3)
      end
    end

    context "when maximum rebill attempts are reached" do
      it "stops attempting further rebills" do
        allow(PaymentGateway).to receive(:create_payment_intent)
          .and_return({ status: "insufficient_funds" })
        allow(RebillScheduler).to receive(:schedule_one_week)

        service = described_class.new(subscription_id, initial_amount, 3)
        result = service.call!

        expect(result).not_to include("Rescheduled rebilling")
        expect(service.instance_variable_get(:@scheduled_count)).to eq(3)
        expect(PaymentAttempt.count).to eq(4)
        expect(PaymentAttempt.pluck(:status)).to all(eq("insufficient_funds"))
        expect(RebillScheduler).not_to have_received(:schedule_one_week)
      end
    end

    context "when the amount is zero" do
      let(:zero_amount) { 0.0 }

      it "does not attempt any payments and does not schedule a rebill" do
        allow(PaymentGateway).to receive(:create_payment_intent)
        allow(RebillScheduler).to receive(:schedule_one_week)

        service = described_class.new(subscription_id, zero_amount)
        result = service.call!

        expect(result).to eq("")
        expect(PaymentGateway).not_to have_received(:create_payment_intent)
        expect(PaymentAttempt.count).to eq(0)
        expect(RebillScheduler).not_to have_received(:schedule_one_week)
      end
    end
  end
end
