require 'digest'

module DeviseInvitable
  invitation_base =
    if defined?(ActiveRecord::Base)
      ActiveRecord::Base
    else
      Object
    end

  class Invitation < invitation_base
    attr_accessor :transient_invite_key

    self.table_name = 'devise_invitations' if respond_to?(:table_name=)

    if defined?(Mongoid::Document) && !defined?(ActiveRecord::Base)
      include Mongoid::Document
      include Mongoid::Timestamps

      store_in collection: 'devise_invitations'

      field :invitation_token, type: String
      field :invitation_created_at, type: Time
      field :invitation_sent_at, type: Time
      field :invitation_accepted_at, type: Time
      field :superseded_at, type: Time
      field :superseded_reason, type: String
      field :revoked_at, type: Time
      field :resource_created_at, type: Time
      field :invite_key, type: Hash, default: {}
      field :invite_key_digest, type: String
      field :invitable_type, type: String
      field :invitable_id
      field :invited_by_type, type: String
      field :invited_by_id

      index({ invitation_token: 1 }, unique: true, sparse: true)
      index({ invitable_type: 1, invitable_id: 1 })
      index({ invited_by_type: 1, invited_by_id: 1 })
      index({ invitable_type: 1, invite_key_digest: 1 })
    end

    belongs_to :invitable, polymorphic: true, optional: true
    invited_by_options = { polymorphic: true, optional: true, autosave: true }
    if defined?(ActiveRecord::Base) && Devise.invited_by_counter_cache
      invited_by_options[:counter_cache] = Devise.invited_by_counter_cache
    end
    belongs_to :invited_by, **invited_by_options

    before_validation :set_invite_key_digest

    scope :pending, lambda {
      where(invitation_accepted_at: nil, superseded_at: nil, revoked_at: nil)
    }
    if defined?(Mongoid::Document) && !defined?(ActiveRecord::Base)
      scope :provisioning, -> { where(:resource_created_at.ne => nil) }
      scope :accepted, -> { where(:invitation_accepted_at.ne => nil) }
    else
      scope :provisioning, -> { where.not(resource_created_at: nil) }
      scope :accepted, -> { where.not(invitation_accepted_at: nil) }
    end

    def pending?
      invitation_accepted_at.nil? && superseded_at.nil? && revoked_at.nil?
    end

    def provisioning?
      resource_created_at.present?
    end

    def invitation_period_valid?(period)
      period.to_i.zero? || (invitation_created_at && invitation_created_at.utc >= period.ago)
    end

    def invite_key
      value = super
      value.respond_to?(:with_indifferent_access) ? value.with_indifferent_access : value
    end

    def invite_key_for_acceptance
      transient_invite_key.presence || invite_key
    end

    def self.digest_for(resource_type, invite_key)
      components = invite_key.to_h.map { |key, value| [key.to_s, value.to_s] }.sort.flatten
      Digest::SHA256.hexdigest(([resource_type] + components).join("\0"))
    end

    private

      def set_invite_key_digest
        return if transient_invite_key.nil? && invite_key.blank? && invite_key_digest.present?

        self.invite_key_digest = self.class.digest_for(invitable_type, invite_key_for_acceptance)
        self.invite_key = {} unless transient_invite_key.nil?
      end
  end
end
