# frozen_string_literal: true

require Rails.root.join("lib/demo/checkins")

namespace :demo do
  namespace :checkins do
    desc "Show check-in status for a user (EMAIL=...)"
    task status: :environment do
      status = Demo::Checkins.status(ENV["EMAIL"])

      puts "Email: #{status[:email]}"
      puts "State: #{status[:state]}"
      puts "Attempts: #{status[:checkin_attempts_sent]}/#{status[:effective_checkin_attempts]}"
      puts "Next check-in at: #{status[:next_checkin_at]}"
      puts "Last attempt at: #{status[:last_checkin_attempt_at]}"
      puts "Cooldown warning at: #{status[:cooldown_warning_sent_at]}"
      puts "Delivery due at: #{status[:delivery_due_at]}"
      puts "Trusted contact pause active: #{status[:trusted_contact_pause_active]}"
    rescue Demo::Checkins::DemoError => e
      abort e.message
    end

    desc "Advance the next check-in step and send emails (EMAIL=...)"
    task advance: :environment do
      user = Demo::Checkins.advance!(ENV["EMAIL"])

      puts "Advanced #{user.email}: state=#{user.state} attempts=#{user.checkin_attempts_sent}/#{user.effective_checkin_attempts}"
    rescue Demo::Checkins::DemoError => e
      abort e.message
    end

    desc "Force delivery and send emails (EMAIL=...)"
    task deliver: :environment do
      user = Demo::Checkins.deliver!(ENV["EMAIL"])

      if user.delivered?
        puts "Delivered for #{user.email}"
      else
        puts "Delivery blocked for #{user.email} (state=#{user.state})"
      end
    rescue Demo::Checkins::DemoError => e
      abort e.message
    end

    desc "Simulate time passing and run check-ins (EMAIL=..., DAYS=...)"
    task advance_days: :environment do
      user = Demo::Checkins.advance_days!(ENV["EMAIL"], ENV["DAYS"])

      puts "Advanced time for #{user.email}: state=#{user.state} attempts=#{user.checkin_attempts_sent}/#{user.effective_checkin_attempts}"
    rescue Demo::Checkins::DemoError => e
      abort e.message
    end
  end
end
