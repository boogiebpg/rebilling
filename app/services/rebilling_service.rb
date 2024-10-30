# frozen_string_literal: true

class RebillingService
  RETRY_PERCENTAGES = [100, 75, 50, 25].freeze
  MAX_SCHEDULED_REBILLS = 3

  class PaymentFailedError < StandardError; end

  class UnexpectedPaymentStatusError < StandardError
    def initialize(status)
      super("Received unexpected payment status: #{status}")
    end
  end

  def initialize(subscription_id, amount, scheduled_count = 0)
    @subscription_id = subscription_id
    @original_amount = amount
    @remaining_balance = amount
    @scheduled_count = scheduled_count
    @attempt_count = 0
  end

  def call!
    result = ""
    RETRY_PERCENTAGES.each do |percentage|
      break if @remaining_balance <= 0

      result = attempt_charge(percentage)
      break if result.include?("Success")
    end
    schedule_partial_rebill_if_needed(result)
    result
  end

  private

  def attempt_charge(percentage)
    current_amount = @original_amount * percentage / 100
    response = make_payment_intent(current_amount)
    log_attempt(current_amount, response, @attempt_count += 1)
    handle_response(response, current_amount)
  end

  def handle_response(response, current_amount)
    case response[:status]
    when "success"
      process_successful_charge(current_amount)
    when "insufficient_funds"
      "Insufficient Funds."
    when "failed"
      raise PaymentFailedError,
            "Failed payment for subscription #{@subscription_id} on attempt #{@attempt_count}"
    else
      raise UnexpectedPaymentStatusError, response[:status]
    end
  end

  def process_successful_charge(amount)
    @remaining_balance -= amount
    "Success. Charged amount: #{amount}."
  end

  def schedule_partial_rebill_if_needed(result)
    if @remaining_balance.positive? && @scheduled_count < MAX_SCHEDULED_REBILLS
      schedule_partial_rebill
      result + " Rescheduled rebilling with amount: #{@remaining_balance}"
    else
      result
    end
  end

  def make_payment_intent(amount)
    PaymentGateway.create_payment_intent(amount, @subscription_id)
  end

  def log_attempt(amount, response, attempt_count)
    PaymentAttempt.create!(
      subscription_id: @subscription_id,
      amount: amount,
      status: response[:status],
      attempt_count: attempt_count,
      scheduled_count: @scheduled_count,
    )

    log_message = "Attempted to charge #{amount} for subscription #{@subscription_id}. Status: #{response[:status]}"
    Rails.logger.info(log_message)
  end

  def schedule_partial_rebill
    RebillScheduler.schedule_one_week(@subscription_id, @remaining_balance, @scheduled_count + 1)
  end
end
