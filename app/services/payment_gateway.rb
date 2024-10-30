# frozen_string_literal: true

class PaymentGateway
  def self.create_payment_intent(_amount, _subscription_id)
    # Simulate response from payment API endpoint
    {
      status: %w[success insufficient_funds failed].sample,
    }
  end
end
