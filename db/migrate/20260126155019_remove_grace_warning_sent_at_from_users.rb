class RemoveGraceWarningSentAtFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :grace_warning_sent_at, :datetime
  end
end
