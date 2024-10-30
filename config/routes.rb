# frozen_string_literal: true

Rails.application.routes.draw do
  post "/paymentIntents/create", to: "payment_intents#create"
end
