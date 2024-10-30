# frozen_string_literal: true

require "rails_helper"

RSpec.describe RebillScheduler do
  describe ".schedule_one_week" do
    let(:subscription_id) { "test_subscription" }
    let(:amount) { 50.0 }
    let(:scheduled_count) { 1 }

    it "schedules a RebillJob with the correct parameters" do
      expect(RebillJob).to receive(:set).with(wait: 1.week).and_return(double(perform_later: true))

      described_class.schedule_one_week(subscription_id, amount, scheduled_count)
    end
  end
end
