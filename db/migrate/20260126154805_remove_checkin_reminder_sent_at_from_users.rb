class RemoveCheckinReminderSentAtFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :checkin_reminder_sent_at, :datetime
  end
end
