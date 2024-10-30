# frozen_string_literal: true

class CreatePaymentAttempts < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_attempts do |t|
      t.integer :subscription_id
      t.decimal :amount
      t.string :status
      t.integer :attempt_count
      t.integer :scheduled_count

      t.timestamps
    end
  end
end
