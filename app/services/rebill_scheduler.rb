# frozen_string_literal: true

class RebillScheduler
  def self.schedule_one_week(subscription_id, amount, scheduled_count)
    message = "Scheduling partial rebill for subscription #{subscription_id} " \
              "with amount #{amount} in one week. Scheduled count: #{scheduled_count}"
    Rails.logger.info(message)

    # Schedule the rebill with incremented `scheduled_count`
    RebillJob.set(wait: 1.week).perform_later(subscription_id, amount, scheduled_count)
  end
end
