# frozen_string_literal: true

module Devise
  module Models
    module Invitable
      # Configures invitation associations, callbacks, and scopes for each ORM.
      module ModelSetup
        private

        def configure_invitation_associations
          has_many :devise_invitations,
                   as: :invitable,
                   class_name: 'DeviseInvitable::Invitation',
                   dependent: :nullify,
                   autosave: true
          before_destroy :destroy_devise_invitations_if_configured, prepend: true
          configure_pending_invitations_association
        end

        def configure_pending_invitations_association
          if defined?(Mongoid::Document) && self < Mongoid::Document
            # rubocop:disable Rails/RedundantForeignKey -- Mongoid infers _id when inverse_of is false.
            has_many :pending_invitations,
                     as: :invitable,
                     class_name: 'DeviseInvitable::Invitation',
                     foreign_key: :invitable_id,
                     inverse_of: false,
                     scope: -> { pending.provisioning }
            # rubocop:enable Rails/RedundantForeignKey
          else
            has_many :pending_invitations,
                     -> { pending.provisioning },
                     as: :invitable,
                     class_name: 'DeviseInvitable::Invitation',
                     foreign_key: :invitable_id,
                     inverse_of: false
          end
        end

        def configure_invitation_callbacks
          extend ActiveModel::Callbacks

          define_model_callbacks :invitation_created
          define_model_callbacks :invitation_accepted
          after_save :resolve_invitations_after_registration!, if: :registering_directly
        end

        def configure_invitation_scopes
          if defined?(Mongoid::Document) && self < Mongoid::Document
            configure_mongoid_invitation_scopes
          elsif defined?(ActiveRecord::Base) && self < ActiveRecord::Base
            configure_active_record_invitation_scopes
          end
        end

        def configure_mongoid_invitation_scopes
          scope :created_by_invite, lambda {
            ids = DeviseInvitable::Invitation.provisioning
                    .where(invitable_type: devise_invitable_base_class.name)
                    .pluck(:invitable_id)
            where(:id.in => ids)
          }
          scope :invitation_not_accepted, lambda {
            ids = DeviseInvitable::Invitation.pending.provisioning
                    .where(invitable_type: devise_invitable_base_class.name)
                    .pluck(:invitable_id)
            where(:id.in => ids)
          }
          scope :invitation_accepted, lambda {
            ids = DeviseInvitable::Invitation.accepted
                    .where(invitable_type: devise_invitable_base_class.name)
                    .pluck(:invitable_id)
            where(:id.in => ids)
          }
          configure_mongoid_no_active_invitation_scope
        end

        def configure_mongoid_no_active_invitation_scope
          scope :no_active_invitation, lambda {
            ids = DeviseInvitable::Invitation.pending.where(invitable_type: devise_invitable_base_class.name)
                    .where(:invitable_id.ne => nil).pluck(:invitable_id)
            where(:id.nin => ids)
          }
        end

        def configure_active_record_invitation_scopes
          scope :created_by_invite, lambda {
            invitation_ids = DeviseInvitable::Invitation.provisioning
                               .where(invitable_type: devise_invitable_base_class.name)
                               .select(:invitable_id)
            where(id: invitation_ids)
          }
          scope :invitation_not_accepted, lambda {
            invitation_ids = DeviseInvitable::Invitation.pending.provisioning
                               .where(invitable_type: devise_invitable_base_class.name)
                               .select(:invitable_id)
            where(id: invitation_ids)
          }
          scope :invitation_accepted, lambda {
            invitation_ids = DeviseInvitable::Invitation.accepted
                               .where(invitable_type: devise_invitable_base_class.name)
                               .select(:invitable_id)
            where(id: invitation_ids)
          }
          configure_active_record_no_active_invitation_scope
          initialize_active_record_invitation_callbacks
        end

        def configure_active_record_no_active_invitation_scope
          scope :no_active_invitation, lambda {
            invitation_ids = DeviseInvitable::Invitation.pending
                               .where(invitable_type: devise_invitable_base_class.name)
                               .where.not(invitable_id: nil)
                               .select(:invitable_id)
            where.not(id: invitation_ids)
          }
        end

        def initialize_active_record_invitation_callbacks
          callbacks = %i[
            before_invitation_created
            after_invitation_created
            before_invitation_accepted
            after_invitation_accepted
          ]

          callbacks.each do |callback_method|
            send callback_method
          end
        end
      end
    end
  end
end
