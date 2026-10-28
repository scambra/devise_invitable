module DeviseInvitable
  class Migrator
    BATCH_SIZE = 1_000

    LEGACY_FIELDS = %w[
      invitation_token invitation_created_at invitation_sent_at
      invitation_accepted_at invited_by_id invited_by_type
    ].freeze

    def self.call(model_class)
      new(model_class).call
    end

    def initialize(model_class)
      unless defined?(Mongoid::Document) && model_class < Mongoid::Document
        raise ArgumentError, 'DeviseInvitable::Migrator only supports Mongoid models'
      end

      @model_class = model_class
    end

    def call
      migrated = 0
      each_legacy_resource_batch do |resources|
        migrated_identities = migrated_identities_for(resources)
        resources_to_migrate = resources.reject do |resource|
          migrated_identities.include?(migration_identity(resource))
        end

        insert_invitations(resources_to_migrate)
        remove_legacy_fields(resources)
        migrated += resources_to_migrate.size
      end
      migrated
    end

    private

      attr_reader :model_class

      def resources_with_legacy_invitations
        model_class.where(:invitation_created_at.ne => nil)
      end

      def each_legacy_resource_batch(&block)
        resources_with_legacy_invitations
          .batch_size(BATCH_SIZE)
          .each_slice(BATCH_SIZE, &block)
      end

      def migrated_identities_for(resources)
        resource_ids = resources.map(&:id)
        DeviseInvitable::Invitation.where(
          invitable_type: model_class.devise_invitable_base_class.name
        ).in(
          invitable_id: resource_ids
        ).pluck(
          :invitable_id, :invitation_created_at
        ).to_h { |identity| [identity, true] }
      end

      def migration_identity(resource)
        [resource.id, legacy_value(resource, 'invitation_created_at')]
      end

      def insert_invitations(resources)
        return if resources.empty?

        now = Time.now.utc
        attributes = resources.map { |resource| invitation_attributes(resource, now) }
        DeviseInvitable::Invitation.collection.insert_many(attributes)
      end

      def invitation_attributes(resource, now)
        created_at = legacy_value(resource, 'invitation_created_at')
        invite_key = invite_key_for(resource)
        {
          invitation_token: legacy_value(resource, 'invitation_token'),
          invitation_created_at: created_at,
          invitation_sent_at: legacy_value(resource, 'invitation_sent_at'),
          invitation_accepted_at: legacy_value(resource, 'invitation_accepted_at'),
          resource_created_at: created_at,
          invite_key: invite_key,
          invite_key_digest: DeviseInvitable::Invitation.digest_for(
            model_class.devise_invitable_base_class.name,
            invite_key
          ),
          invitable_type: model_class.devise_invitable_base_class.name,
          invitable_id: resource.id,
          invited_by_type: legacy_value(resource, 'invited_by_type'),
          invited_by_id: legacy_value(resource, 'invited_by_id'),
          created_at: now,
          updated_at: now
        }
      end

      def invite_key_for(resource)
        model_class.invite_key_fields.each_with_object({}) do |key, values|
          values[key] = resource.public_send(key)
        end
      end

      def legacy_value(resource, field)
        resource.attributes[field]
      end

      def remove_legacy_fields(resources)
        return if resources.empty?

        model_class.in(id: resources.map(&:id)).unset(*LEGACY_FIELDS)
      end
  end
end
