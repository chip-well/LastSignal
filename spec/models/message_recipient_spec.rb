# frozen_string_literal: true

require "rails_helper"

RSpec.describe MessageRecipient, type: :model do
  describe "validations" do
    subject { build(:message_recipient) }

    it { should validate_presence_of(:encrypted_msg_key_b64u) }
    it { should validate_presence_of(:envelope_algo) }
    it { should validate_presence_of(:envelope_version) }
    it { should validate_numericality_of(:envelope_version).only_integer.is_greater_than(0) }

    describe "recipient_has_key validation" do
      it "requires recipient to have accepted and have a key" do
        recipient = create(:recipient, state: "invited")
        mr = build(:message_recipient, recipient: recipient)
        expect(mr).not_to be_valid
        expect(mr.errors[:recipient]).to include("must have accepted invite and registered a public key")
      end

      it "accepts recipient with key" do
        recipient = create(:recipient, :accepted)
        mr = build(:message_recipient, recipient: recipient)
        expect(mr).to be_valid
      end
    end

    describe "delivery_delay_hours validation" do
      let(:recipient) { create(:recipient, :accepted) }
      let(:message) { create(:message, user: recipient.user) }

      it "allows 0" do
        mr = build(:message_recipient, message: message, recipient: recipient, delivery_delay_hours: 0)
        expect(mr).to be_valid
      end

      it "allows positive values within limit" do
        mr = build(:message_recipient, message: message, recipient: recipient, delivery_delay_hours: 24 * 30)
        expect(mr).to be_valid
      end

      it "rejects negative values" do
        mr = build(:message_recipient, message: message, recipient: recipient, delivery_delay_hours: -1)
        expect(mr).not_to be_valid
        expect(mr.errors[:delivery_delay_hours]).to be_present
      end

      it "rejects values exceeding max delay" do
        max_hours = AppConfig.message_recipient_max_delivery_delay_days * 24
        mr = build(:message_recipient, message: message, recipient: recipient, delivery_delay_hours: max_hours + 1)
        expect(mr).not_to be_valid
        expect(mr.errors[:delivery_delay_hours]).to be_present
      end
    end
  end

  describe "associations" do
    it { should belong_to(:message) }
    it { should belong_to(:recipient) }
  end

  describe "#available_at" do
    let(:user) { create(:user, :delivered, delivered_at: Time.current) }
    let(:message) { create(:message, user: user) }
    let(:recipient) { create(:recipient, :accepted, user: user) }

    it "returns nil if user is not delivered" do
      user.update!(state: :active, delivered_at: nil)
      mr = create(:message_recipient, message: message, recipient: recipient, delivery_delay_hours: 24)
      expect(mr.available_at).to be_nil
    end

    it "returns delivered_at + delay when user is delivered" do
      delivered_at = user.delivered_at
      mr = create(:message_recipient, message: message, recipient: recipient, delivery_delay_hours: 48)
      expect(mr.available_at).to be_within(1.second).of(delivered_at + 48.hours)
    end

    it "returns delivered_at when delay is 0" do
      delivered_at = user.delivered_at
      mr = create(:message_recipient, message: message, recipient: recipient, delivery_delay_hours: 0)
      expect(mr.available_at).to be_within(1.second).of(delivered_at)
    end
  end

  describe "#available?" do
    let(:user) { create(:user, :delivered, delivered_at: 2.days.ago) }
    let(:message) { create(:message, user: user) }
    let(:recipient) { create(:recipient, :accepted, user: user) }

    it "returns true when delay is 0" do
      mr = create(:message_recipient, message: message, recipient: recipient, delivery_delay_hours: 0)
      expect(mr.available?).to be true
    end

    it "returns true when delay has passed" do
      mr = create(:message_recipient, message: message, recipient: recipient, delivery_delay_hours: 24)
      expect(mr.available?).to be true
    end

    it "returns false when delay has not passed" do
      mr = create(:message_recipient, message: message, recipient: recipient, delivery_delay_hours: 72)
      expect(mr.available?).to be false
    end
  end

  describe "#delivery_delay_days" do
    it "converts hours to days" do
      mr = build(:message_recipient, delivery_delay_hours: 72)
      expect(mr.delivery_delay_days).to eq(3)
    end

    it "returns 0 for nil delay" do
      mr = build(:message_recipient, delivery_delay_hours: nil)
      expect(mr.delivery_delay_days).to eq(0)
    end
  end
end
