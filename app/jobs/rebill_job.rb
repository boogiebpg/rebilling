# frozen_string_literal: true

class RebillJob < ApplicationJob
  queue_as :default

  def perform(subscription_id, amount, scheduled_count)
    rebilling_service = RebillingService.new(subscription_id, amount, scheduled_count)
    rebilling_service.call!
  end
end
