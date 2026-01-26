# frozen_string_literal: true

class DeliverMessagesJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    return unless user.delivered?

    Rails.logger.info "[DeliverMessagesJob] Delivering messages for user #{user_id}"

    # Get all recipients with accepted keys
    recipients_with_messages = user.recipients.with_keys.includes(:messages)

    recipients_with_messages.find_each do |recipient|
      message_recipients = recipient.message_recipients
        .joins(:message)
        .where(messages: { user_id: user.id })
        .includes(:message)

      next if message_recipients.empty?

      available_count = message_recipients.count(&:available?)
      delayed_mrs = message_recipients.reject(&:available?)

      # Generate delivery token
      delivery_token, raw_token = DeliveryToken.generate_for(recipient)

      # Send delivery email with delay info
      RecipientMailer.delivery(recipient, raw_token, available_count, delayed_mrs).deliver_later

      safe_audit_log(
        action: "recipient_delivery_sent",
        user: user,
        actor_type: "system",
        metadata: {
          recipient_id: recipient.id,
          available_count: available_count,
          delayed_count: delayed_mrs.count
        }
      )

      Rails.logger.info "[DeliverMessagesJob] Sent delivery email to recipient #{recipient.id} with #{available_count} available, #{delayed_mrs.count} delayed messages"
    end
  end

  def safe_audit_log(**args)
    AuditLog.log(**args)
  rescue StandardError => e
    Rails.logger.error("[DeliverMessagesJob] AuditLog failed: #{e.class}: #{e.message}")
  end
end
