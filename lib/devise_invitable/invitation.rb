require 'digest'

module DeviseInvitable
  invitation_base =
    if defined?(ActiveRecord::Base)
      ActiveRecord::Base
    else
      Object
    end

  # Persistent invitation state shared by every invitable resource.
  #
  # An invitation may exist without an +invitable+ resource until acceptance.
  # Its invite keys are normally carried only in the encrypted acceptance token;
  # they may be stored temporarily when deferred delivery is configured.
  class Invitation < invitation_base
    # Application data decoded from the acceptance token for the current
    # invitation operation. It is not persisted by Devise Invitable.
    attr_accessor :invitation_data

    # Normalized invite keys retained in memory while an invitation is created
    # or delivered. They are persisted only when deferred delivery requires it.
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

    invitable_options = { polymorphic: true, optional: true }
    if defined?(Mongoid::Document) && !defined?(ActiveRecord::Base)
      # Mongoid cannot infer a polymorphic inverse when the parent exposes both
      # the complete and scoped invitation associations.
      invitable_options[:inverse_of] = false
    end
    belongs_to :invitable, **invitable_options
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

    # Returns whether the invitation has not been accepted, superseded, or
    # revoked. A pending invitation may still be unsent or expired.
    def pending?
      invitation_accepted_at.nil? && superseded_at.nil? && revoked_at.nil?
    end

    # Returns whether this invitation created a placeholder resource.
    def provisioning?
      resource_created_at.present?
    end

    # Returns whether the invitation was sent within +period+. A zero or +nil+
    # period means that a sent invitation does not expire.
    def invitation_period_valid?(period)
      invitation_sent_at &&
        (period.to_i.zero? || invitation_sent_at.utc >= period.ago)
    end

    # Delivers a pending, unsent invitation synchronously.
    #
    # A resource-less invitation is reconstructed from its stored invite key,
    # so +store_invite_keys_until_delivery+ must have been enabled before the
    # invitation was created. Successful delivery clears the stored invite key,
    # sets +invitation_sent_at+, and makes subsequent calls no-ops.
    def deliver(options = {})
      DeviseInvitable::InvitationDelivery.call(self, options: options)
    end

    # Enqueues a pending, unsent invitation with the configured invitation
    # delivery job.
    #
    # A reloaded resource-less invitation requires
    # +store_invite_keys_until_delivery+ so the job can reconstruct its invitee.
    def deliver_later(options = {})
      DeviseInvitable::InvitationDelivery.enqueue(self, options: options)
    end

    # Returns stored invite keys with indifferent access when supported by the
    # underlying value.
    def invite_key
      value = super
      value.respond_to?(:with_indifferent_access) ? value.with_indifferent_access : value
    end

    # Returns transient invite keys when present, otherwise the stored keys.
    def invite_key_for_acceptance
      transient_invite_key.presence || invite_key
    end

    # Clears both transient and stored invite-key values on this record after
    # delivery. The delivery service then persists the change.
    def clear_invite_key
      self.transient_invite_key = nil
      self.invite_key = {} if invite_key.present?
    end

    # Returns the stable SHA-256 digest used to match +invite_key+ values for a
    # particular +resource_type+ without persisting those values in plaintext.
    def self.digest_for(resource_type, invite_key)
      components = invite_key.to_h.map { |key, value| [key.to_s, value.to_s] }.sort.flatten
      Digest::SHA256.hexdigest(([resource_type] + components).join("\0"))
    end

    private

      def set_invite_key_digest
        return if transient_invite_key.nil? && invite_key.blank? && invite_key_digest.present?

        self.invite_key_digest = self.class.digest_for(invitable_type, invite_key_for_acceptance)
        unless transient_invite_key.nil?
          self.invite_key =
            if invitable_type.constantize.store_invite_keys_until_delivery
              transient_invite_key
            else
              {}
            end
        end
      end
  end
end
