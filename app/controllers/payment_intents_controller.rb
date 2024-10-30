# frozen_string_literal: true

class PaymentIntentsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :check_params

  def create
    subscription_id = params[:subscription_id]
    amount = params[:amount].to_f

    begin
      rebilling_service = RebillingService.new(subscription_id, amount)
      result = rebilling_service.call!

      # success or insufficient_funds response received
      render json: { message: result }, status: :ok
    rescue RebillingService::PaymentFailedError, RebillingService::UnexpectedPaymentStatusError => e
      Rails.logger.error(e.message)

      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  private

  def check_params
    return unless params[:subscription_id].nil? || params[:amount].nil?

    render json: { error: "Invalid parameters" },
           status: :bad_request
  end
end
