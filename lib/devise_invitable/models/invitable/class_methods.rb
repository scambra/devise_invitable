# frozen_string_literal: true

require 'devise_invitable/models/invitable/token_lookup'

module Devise
  module Models
    module Invitable
      # Provides the model API for inviting resources and configuring invitations.
      module ClassMethods
        include TokenLookup

        # Returns the root persistence class used as the invitation's
        # polymorphic +invitable_type+.
        def devise_invitable_base_class
          if respond_to?(:base_class)
            base_class
          elsif respond_to?(:root_class)
            root_class
          else
            self
          end
        end

        # Returns the configured invite-key field names.
        def invite_key_fields
          invite_key.keys
        end

        # Internal implementation shared by .invite! and .invite_mail!.
        def _invite(attributes = {}, invited_by = nil, options = {}, &block)
          invite_key_array = invite_key_fields
          skip_invitation = attributes.delete(:skip_invitation)
          attributes_hash = extract_invite_key_attributes(attributes, invite_key_array)

          ensure_unique_invite_key_match!(invite_key_array, attributes_hash)
          invitable = find_or_initialize_with_errors(invite_key_array, attributes_hash)
          invitable.assign_attributes(attributes_hash)
          # Association writers may persist changes immediately. Reject an
          # existing resource before assigning non-key attributes or yielding.
          if invitation_resource_unavailable?(invitable)
            invite_key_array.each do |key|
              invitable.add_taken_error(key)
            end
            return [invitable, nil]
          end

          invitable.assign_attributes(attributes)
          invitable.skip_invitation = skip_invitation unless skip_invitation.nil?
          invitable.invited_by_for_next_invitation = invited_by
          prepare_invitation_resource(invitable, attributes_hash)

          resource_attribute_names = attributes.keys.map(&:to_sym)
          changes_before_block = invitable.changes.dup
          yield invitable if block_given?
          ensure_no_resource_attributes!(invitable, resource_attribute_names, changes_before_block)
          mail = invitable.invite!(invited_by, options.merge(validate: false)) if invitable.errors.empty?
          [invitable, mail]
        end

        # Creates an invitation and returns the invited resource.
        #
        # +attributes+ must include every configured invite key. By default only
        # a DeviseInvitable::Invitation is persisted; enable
        # +create_resource_on_invitation+ to create a placeholder resource and
        # persist additional resource attributes immediately.
        #
        # The optional +invited_by+ resource is stored on the invitation.
        # +options[:invitation_data]+ may contain a small JSON-compatible hash to
        # carry in the encrypted acceptance token. Set +:skip_invitation+ in
        # +attributes+ (or set #skip_invitation in the block) to store the
        # invitation without sending its email.
        def invite!(attributes = {}, invited_by = nil, options = {}, &block)
          attr_hash = ActiveSupport::HashWithIndifferentAccess.new(attributes.to_h)
          _invite(attr_hash, invited_by, options, &block).first
        end

        # Creates an invitation like .invite!, but returns the mail delivery
        # result instead of the invited resource.
        def invite_mail!(attributes = {}, invited_by = nil, options = {}, &block)
          _invite(attributes, invited_by, options, &block).last
        end

        # Accepts an invitation and returns the invited resource.
        #
        # +attributes+ must include +:invitation_token+ and may include the
        # password, password confirmation, and other permitted resource
        # attributes. An invalid token returns a new resource with an error on
        # +invitation_token+.
        def accept_invitation!(attributes = {})
          original_token = attributes.delete(:invitation_token)
          invitable = find_by_invitation_token(original_token, false)
          if invitable.errors.empty?
            if invitable.resource_previously_provisioned?
              attributes.delete(:password)
              attributes.delete(:password_confirmation)
            end
            invitable.assign_attributes(attributes)
            invitable.accept_invitation!
          end
          invitable
        end

        # Returns pending invitations whose normalized invite keys match
        # +attributes+.
        def pending_invitations_for(attributes)
          keys = normalized_invite_keys(attributes)
          resource_type = devise_invitable_base_class.name
          digest_candidates =
            DeviseInvitable::Invitation.digest_candidates_for(
              resource_type,
              keys,
              allow_legacy: allow_legacy_invite_key_digests
            )
          invitations =
            digest_candidates.flat_map do |digest|
              DeviseInvitable::Invitation.to_adapter.find_all(
                conditions: {
                  invitation_accepted_at: nil,
                  superseded_at: nil,
                  revoked_at: nil,
                  invitable_type: resource_type,
                  invite_key_digest: digest
                }
              ).to_a
            end
          invitations.uniq { |invitation| invitation.id.to_s }
        end

        # Extracts and normalizes configured invite keys from +attributes+ using
        # the model's whitespace and case-insensitivity settings.
        def normalized_invite_keys(attributes)
          attributes.to_h.with_indifferent_access.slice(*invite_key_fields).each_with_object({}) do |(key, value), keys|
            value = value.to_s.strip if strip_whitespace_keys.include?(key.to_sym)
            value = value.downcase if value.respond_to?(:downcase) && case_insensitive_keys.include?(key.to_sym)
            keys[key] = value
          end
        end

        # Registers a callback to run before an invitation is created.
        def before_invitation_created(*args, &blk)
          set_callback(:invitation_created, :before, *args, &blk)
        end

        # Registers a callback to run after an invitation is created.
        def after_invitation_created(*args, &blk)
          set_callback(:invitation_created, :after, *args, &blk)
        end

        # Registers a callback to run before an invitation is accepted.
        def before_invitation_accepted(*args, &blk)
          set_callback(:invitation_accepted, :before, *args, &blk)
        end

        # Registers a callback to run after an invitation is accepted.
        def after_invitation_accepted(*args, &blk)
          set_callback(:invitation_accepted, :after, *args, &blk)
        end

        Devise::Models.config(self, :invite_for)
        Devise::Models.config(self, :validate_on_invite)
        Devise::Models.config(self, :invitation_limit)
        Devise::Models.config(self, :invite_key)
        Devise::Models.config(self, :resend_invitation)
        Devise::Models.config(self, :invited_by_class_name)
        Devise::Models.config(self, :invited_by_foreign_key)
        Devise::Models.config(self, :invited_by_counter_cache)
        Devise::Models.config(self, :allow_insecure_sign_in_after_accept)
        Devise::Models.config(self, :require_password_on_accepting)
        Devise::Models.config(self, :create_resource_on_invitation)
        Devise::Models.config(self, :invitations_dependent)
        Devise::Models.config(self, :store_invite_keys_until_delivery)
        Devise::Models.config(self, :allow_legacy_invite_key_digests)
        Devise::Models.config(self, :deliver_invitation_later)
        Devise::Models.config(self, :supersede_other_invitations_on_accept)

        def invitations_dependent=(value)
          unless DeviseInvitable::INVITATIONS_DEPENDENT_VALUES.include?(value)
            raise ArgumentError, 'invitations_dependent must be :nullify or :destroy'
          end

          @invitations_dependent = value
        end

        # Sets the deprecated +invited_by_class_name+ compatibility option.
        # Invitations always use a polymorphic inviter association.
        def invited_by_class_name=(value)
          DeviseInvitable.warn_deprecated_invited_by_setting(:invited_by_class_name)
          @invited_by_class_name = value
        end

        # Sets the deprecated +invited_by_foreign_key+ compatibility option.
        # Invitations always use +invited_by_id+ and +invited_by_type+.
        def invited_by_foreign_key=(value)
          DeviseInvitable.warn_deprecated_invited_by_setting(:invited_by_foreign_key)
          @invited_by_foreign_key = value
        end

        private

        def extract_invite_key_attributes(attributes, invite_key_array)
          invite_key_array.each_with_object({}) do |key, keys|
            attribute = attributes.delete(key)
            attribute = attribute.to_s.strip if strip_whitespace_keys.include?(key)
            keys[key] = attribute
          end
        end

        def invitation_resource_unavailable?(invitable)
          invitable.persisted? && (invitable.invitation_taken? || !resend_invitation)
        end

        def prepare_invitation_resource(invitable, attributes_hash)
          if create_resource_on_invitation && !(invitable.password || invitable.encrypted_password.present?)
            invitable.password = random_password
          end

          invitable.valid? if validate_on_invite && create_resource_on_invitation
          validate_invitation_resource(invitable, attributes_hash)
        end

        def validate_invitation_resource(invitable, attributes_hash)
          if !create_resource_on_invitation && !resend_invitation && pending_invitations_for(attributes_hash).any?
            invite_key_fields.each { |key| invitable.add_taken_error(key) }
          elsif invitable.new_record?
            invitable.clear_errors_on_valid_keys unless validate_on_invite
          end
        end

        def ensure_no_resource_attributes!(invitable, resource_attribute_names, changes_before_block)
          return if create_resource_on_invitation

          block_attribute_names = invitable.changes.each_with_object([]) do |(attribute, change), names|
            names << attribute.to_sym unless changes_before_block[attribute] == change
          end
          changed_resource_attributes =
            (resource_attribute_names + block_attribute_names).uniq - invite_key_fields.map(&:to_sym)
          return if changed_resource_attributes.empty?

          raise DeviseInvitable::ResourceAttributesRequirePlaceholderError,
                "Cannot assign resource attributes (#{changed_resource_attributes.join(', ')}) when " \
                'create_resource_on_invitation is disabled'
        end

        def ensure_unique_invite_key_match!(required_attributes, attributes)
          filtered_attributes = attributes.to_h.with_indifferent_access
                                  .slice(*required_attributes)
                                  .delete_if { |_key, value| value.blank? }
          return unless filtered_attributes.size == required_attributes.size

          filtered_attributes = devise_parameter_filter.filter(filtered_attributes)
          matches = to_adapter.find_all(conditions: filtered_attributes, limit: 2).to_a
          return unless matches.many?

          raise DeviseInvitable::AmbiguousInviteKeyError,
                "Invite key matches multiple #{devise_invitable_base_class.name} records"
        end

        # The random password, as set after an invitation, must conform
        # to any password format validation rules of the application.
        # This default fixes the most common scenarios: Passwords must contain
        # lower + upper case, a digit and a symbol.
        # For more unusual rules, this method can be overridden.
        def random_password
          length = respond_to?(:password_length) ? password_length : Devise.password_length

          prefix = 'aA1!'
          prefix + Devise.friendly_token(length.last - prefix.length)
        end
      end
    end
  end
end
