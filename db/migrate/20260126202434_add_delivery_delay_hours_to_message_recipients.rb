class AddDeliveryDelayHoursToMessageRecipients < ActiveRecord::Migration[8.0]
  def change
    add_column :message_recipients, :delivery_delay_hours, :integer, default: 0, null: false
  end
end
