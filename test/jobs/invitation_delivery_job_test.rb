require 'test_helper'
require 'model_tests_helper'

class InvitationDeliveryJobTest < ActiveSupport::TestCase
  setup do
    @invitation_delivery_job = Devise.invitation_delivery_job
    @invitation_delivery_queue_name = Devise.invitation_delivery_queue_name
    @create_resource_on_invitation = User.create_resource_on_invitation
    @store_invite_keys_until_delivery = User.store_invite_keys_until_delivery
    @deliver_invitation_later = User.deliver_invitation_later
    User.create_resource_on_invitation = false
    User.deliver_invitation_later = false
    DeviseInvitable::Invitation.delete_all
  end

  teardown do
    Devise.invitation_delivery_job = @invitation_delivery_job
    Devise.invitation_delivery_queue_name = @invitation_delivery_queue_name
    User.create_resource_on_invitation = @create_resource_on_invitation
    User.store_invite_keys_until_delivery = @store_invite_keys_until_delivery
    User.deliver_invitation_later = @deliver_invitation_later
  end

  test 'deliver_later passes a persisted invitation and acceptance token to the configured job' do
    job_class = Class.new do
      class << self
        attr_reader :arguments

        def perform_later(*arguments)
          @arguments = arguments
          :enqueued
        end
      end
    end
    Devise.invitation_delivery_job = job_class

    user = User.invite!(email: 'queued@example.com', skip_invitation: true)
    invitation = user.current_invitation

    assert_equal :enqueued, invitation.deliver_later
    enqueued_invitation, acceptance_token, options = job_class.arguments
    assert_equal invitation, enqueued_invitation
    assert_equal({}, options)
    assert_equal 'queued@example.com',
      DeviseInvitable::AcceptanceToken.decode(acceptance_token).dig(:invite_key, :email)

    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      DeviseInvitable::InvitationDeliveryJob.perform_now(
        DeviseInvitable::Invitation.find(invitation.id),
        acceptance_token,
        options
      )
    end
    assert_predicate invitation.reload, :invitation_sent_at
    assert_equal ['queued@example.com'], ActionMailer::Base.deliveries.last.to
  end

  test 'the default job delivers a reloaded resource-less invitation from stored keys' do
    User.store_invite_keys_until_delivery = true
    user = User.invite!(email: 'stored@example.com', skip_invitation: true)
    invitation = DeviseInvitable::Invitation.find(user.current_invitation.id)

    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      DeviseInvitable::InvitationDeliveryJob.perform_now(invitation)
    end

    assert_predicate invitation.reload, :invitation_sent_at
    assert_empty invitation.invite_key
    assert_equal ['stored@example.com'], ActionMailer::Base.deliveries.last.to
  end

  test 'the default job does not enqueue through send_devise_notification' do
    user = User.invite!(email: 'direct@example.com', skip_invitation: true)
    invitation = user.current_invitation
    acceptance_token = user.acceptance_token
    User.any_instance.stubs(:send_devise_notification).raises('must not be called')

    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      DeviseInvitable::InvitationDeliveryJob.perform_now(
        invitation,
        acceptance_token
      )
    end

    assert_predicate invitation.reload, :invitation_sent_at
  end

  test 'the setting enqueues the normal invitation flow with the configured job' do
    job_class = Class.new do
      class << self
        attr_reader :arguments

        def perform_later(*arguments)
          @arguments = arguments
          :enqueued
        end
      end
    end
    Devise.invitation_delivery_job = job_class
    User.deliver_invitation_later = true
    User.any_instance.stubs(:send_devise_notification).raises('must not be called')

    assert_no_difference('ActionMailer::Base.deliveries.size') do
      User.invite!(email: 'configured@example.com')
    end

    invitation, acceptance_token, options = job_class.arguments
    assert_predicate invitation, :persisted?
    assert_nil invitation.invitation_sent_at
    assert_equal({ validate: false }, options)
    assert_equal 'configured@example.com',
      DeviseInvitable::AcceptanceToken.decode(acceptance_token).dig(:invite_key, :email)
  end

  test 'the normal flow keeps using send_devise_notification when the setting is disabled' do
    User.any_instance.expects(:send_devise_notification)
      .with(:invitation_instructions, kind_of(String), { validate: false })
      .returns(:application_delivery)

    assert_equal :application_delivery,
      User.invite_mail!(email: 'application-delivery@example.com')
  end

  test 'the default job uses the configured queue' do
    Devise.invitation_delivery_queue_name = :critical_mailers

    assert_equal 'critical_mailers', DeviseInvitable::InvitationDeliveryJob.new.queue_name
  end

  test 'a reloaded resource-less invitation needs stored keys or an acceptance token' do
    user = User.invite!(email: 'missing@example.com', skip_invitation: true)
    invitation = DeviseInvitable::Invitation.find(user.current_invitation.id)

    assert_raises(DeviseInvitable::MissingInviteKeyError) do
      invitation.deliver_later
    end
  end
end
