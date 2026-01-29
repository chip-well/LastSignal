# frozen_string_literal: true

module Demo
  module Checkins
    class DemoError < StandardError; end

    def self.ensure_demo_env!
      return if Rails.env.development? || Rails.env.test?

      raise DemoError, "Demo check-in helpers are only available in development or test."
    end

    def self.find_user!(email)
      raise DemoError, "EMAIL is required." if email.to_s.strip.empty?

      User.find_by!(email: email.to_s.strip.downcase)
    rescue ActiveRecord::RecordNotFound
      raise DemoError, "User not found for email: #{email}"
    end

    def self.ensure_active_messages!(user)
      return if user.has_active_messages?

      raise DemoError, "User has no active messages with accepted recipients."
    end

    def self.status(email)
      ensure_demo_env!
      user = find_user!(email)

      {
        email: user.email,
        state: user.state,
        checkin_attempts_sent: user.checkin_attempts_sent,
        effective_checkin_attempts: user.effective_checkin_attempts,
        next_checkin_at: user.next_checkin_at,
        last_checkin_attempt_at: user.last_checkin_attempt_at,
        cooldown_warning_sent_at: user.cooldown_warning_sent_at,
        delivery_due_at: user.delivery_due_at,
        trusted_contact_pause_active: user.trusted_contact_pause_active?
      }
    end

    def self.advance!(email)
      ensure_demo_env!
      user = find_user!(email)
      ensure_active_messages!(user)

      raise DemoError, "User is already delivered." if user.delivered?
      raise DemoError, "User is paused. Resume check-ins first." if user.paused?

      if user.cooldown?
        force_delivery_due!(user)
      elsif user.checkin_attempts_sent.to_i.zero?
        force_initial_attempt_due!(user)
      else
        force_followup_attempt_due!(user)
      end

      ProcessCheckinsJob.perform_now
      user.reload
      user
    end

    def self.deliver!(email)
      ensure_demo_env!
      user = find_user!(email)
      ensure_active_messages!(user)

      return user if user.delivered?
      raise DemoError, "User is paused. Resume check-ins first." if user.paused?

      force_delivery_due!(user)
      ProcessCheckinsJob.perform_now
      user.reload
      user
    end

    def self.advance_days!(email, days)
      ensure_demo_env!
      user = find_user!(email)

      days_int = days.to_i
      raise DemoError, "DAYS must be a positive integer." if days_int <= 0

      seconds = days_int.days

      user.update_columns(
        next_checkin_at: shift_time(user.next_checkin_at, seconds),
        last_checkin_attempt_at: shift_time(user.last_checkin_attempt_at, seconds),
        cooldown_warning_sent_at: shift_time(user.cooldown_warning_sent_at, seconds),
        delivered_at: shift_time(user.delivered_at, seconds)
      )

      if (contact = user.trusted_contact)
        contact.update_columns(
          paused_until: shift_time(contact.paused_until, seconds),
          last_pinged_at: shift_time(contact.last_pinged_at, seconds),
          last_confirmed_at: shift_time(contact.last_confirmed_at, seconds),
          token_expires_at: shift_time(contact.token_expires_at, seconds)
        )
      end

      ProcessCheckinsJob.perform_now
      user.reload
      user
    end

    def self.force_initial_attempt_due!(user)
      user.update_columns(
        state: "active",
        next_checkin_at: 2.minutes.ago,
        checkin_attempts_sent: 0,
        last_checkin_attempt_at: nil
      )
    end

    def self.force_followup_attempt_due!(user)
      interval = user.effective_checkin_attempt_interval_hours.hours

      user.update_columns(
        last_checkin_attempt_at: Time.current - interval - 5.minutes
      )
    end

    def self.force_delivery_due!(user)
      interval = user.effective_checkin_attempt_interval_hours.hours

      user.update_columns(
        state: "cooldown",
        cooldown_warning_sent_at: Time.current - interval - 5.minutes
      )
    end

    def self.shift_time(value, seconds)
      return nil if value.nil?

      value - seconds
    end
  end
end
