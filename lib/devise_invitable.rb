# frozen_string_literal: true

# Provides invitation workflows and their integration with Devise.
module DeviseInvitable
  INVITATIONS_DEPENDENT_VALUES = %i[nullify destroy].freeze

  class AmbiguousInviteKeyError < StandardError; end
  class InvitationDataTooLargeError < ArgumentError; end
  class MissingInviteKeyError < StandardError; end
  class ResourceAttributesRequirePlaceholderError < ArgumentError; end

  autoload :AcceptanceToken, 'devise_invitable/acceptance_token'
  autoload :Inviter, 'devise_invitable/inviter'
  autoload :Invitation, 'devise_invitable/invitation'
  autoload :InvitationDelivery, 'devise_invitable/invitation_delivery'
  autoload :InvitationDeliveryJob, 'devise_invitable/invitation_delivery_job'
  autoload :Mailer, 'devise_invitable/mailer'
  autoload :Migrator, 'devise_invitable/migrator'
  autoload :Mapping, 'devise_invitable/mapping'
  autoload :ParameterSanitizer, 'devise_invitable/parameter_sanitizer'

  # Controller integrations loaded by the Rails engine.
  module Controllers
    autoload :Registrations, 'devise_invitable/controllers/registrations'
    autoload :Helpers, 'devise_invitable/controllers/helpers'
  end

  def self.invitation_delivery_job
    job = Devise.invitation_delivery_job
    job = job.constantize if job.respond_to?(:constantize)
    return job if job.respond_to?(:perform_later)

    raise ArgumentError,
          'Devise.invitation_delivery_job must respond to perform_later'
  end

  def self.deprecator
    @deprecator ||= ActiveSupport::Deprecation.new('3.0', 'DeviseInvitable')
  end

  def self.warn_deprecated_invited_by_setting(setting)
    deprecator.warn(
      "The #{setting} setting is deprecated and has no effect. " \
      'Invitations now always use a polymorphic invited_by association ' \
      'with invited_by_id and invited_by_type.'
    )
  end
end

require 'devise'
require 'active_support/deprecation'
require 'devise_invitable/routes'
require 'devise_invitable/rails'
require 'devise_invitable/configuration'

Devise.add_module :invitable, controller: :invitations, model: 'devise_invitable/models',
                              route: { invitation: [nil, :new, :accept] }
