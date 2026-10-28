module DeviseInvitable
  module Inviter
    extend ActiveSupport::Concern

    included do
      has_many :sent_invitations,
        class_name: 'DeviseInvitable::Invitation',
        as: :invited_by,
        dependent: :nullify

      extend ClassMethods
      attr_writer :invitation_limit unless respond_to? :invitation_limit
    end

    def invitation_limit
      stored_limit =
        if invitation_limit_attribute?
          self[:invitation_limit]
        else
          @invitation_limit
        end
      stored_limit || self.class.invitation_limit
    end

    # Return true if this user has invitations left to send
    def has_invitations_left?
      if self.class.invitation_limit.present?
        unless invitation_limit_attribute?
          return sent_invitations.count < self.class.invitation_limit
        end

        if invitation_limit
          return invitation_limit > 0
        else
          return self.class.invitation_limit > 0
        end
      else
        return true
      end
    end

    protected

      def decrement_invitation_limit!
        if self.class.invitation_limit.present?
          return unless invitation_limit_attribute?

          self.invitation_limit ||= self.class.invitation_limit
          self.update_attribute(:invitation_limit, invitation_limit - 1)
        end
      end

      def invitation_limit_attribute?
        (respond_to?(:has_attribute?) && has_attribute?(:invitation_limit)) ||
          (self.class.respond_to?(:fields) && self.class.fields.key?('invitation_limit'))
      end

      module ClassMethods
        Devise::Models.config(self, :invitation_limit)
      end
  end
end
