require 'test_helper'
require 'model_tests_helper'

class SeparateInvitationsTest < ActiveSupport::TestCase
  setup do
    @create_resource_on_invitation = User.create_resource_on_invitation
    DeviseInvitable::Invitation.delete_all
  end

  teardown do
    User.create_resource_on_invitation = @create_resource_on_invitation
  end

  test 'an invitation can be persisted without creating a resource' do
    User.create_resource_on_invitation = false
    registered = User.create!(email: 'registered@example.com', password: '123456789')

    invited = User.invite!(email: 'deferred@example.com')
    invitation = DeviseInvitable::Invitation.first

    assert_predicate invited, :new_record?
    assert_equal 0, User.where(email: 'deferred@example.com').count
    assert_equal({ 'email' => 'deferred@example.com' }, invitation.invite_key.to_h.stringify_keys)
    assert_nil invitation.invitable_id
    assert_nil invitation.resource_created_at
    assert_includes User.no_active_invitation, registered
  end

  test 'accepting one of multiple invitations creates the resource and supersedes the others' do
    User.create_resource_on_invitation = false
    first_inviter = User.create!(email: 'first@example.com', password: '123456789')
    second_inviter = User.create!(email: 'second@example.com', password: '123456789')

    User.invite!({ email: 'multiple@example.com' }, first_inviter)
    first = DeviseInvitable::Invitation.order(:id).first
    User.invite!({ email: 'multiple@example.com' }, second_inviter)
    accepted_token = Thread.current[:token]

    user = User.accept_invitation!(
      invitation_token: accepted_token,
      password: '123456789',
      password_confirmation: '123456789'
    )

    assert_predicate user, :persisted?
    refute_predicate user, :invitation_pending?
    assert DeviseInvitable::Invitation.accepted.where(invitable: user).exists?
    assert_equal 'accepted_other_invitation', first.reload.superseded_reason
    assert_equal first_inviter, first.invited_by
    assert_equal second_inviter, DeviseInvitable::Invitation.accepted.find_by!(invitable: user).invited_by
    assert_equal user, first.invitable
  end

  test 'resending stages the new inviter without changing the previous invitation' do
    User.create_resource_on_invitation = true
    first_inviter = User.create!(email: 'first@example.com', password: '123456789')
    second_inviter = User.create!(email: 'second@example.com', password: '123456789')

    User.invite!({ email: 'multiple@example.com' }, first_inviter)
    first_invitation = DeviseInvitable::Invitation.order(:id).first

    User.invite!({ email: 'multiple@example.com' }, second_inviter) do |invitable|
      assert_equal second_inviter, invitable.invited_by
      assert_equal second_inviter, invitable.invited_by_for_next_invitation
    end

    assert_equal first_inviter, first_invitation.reload.invited_by
    assert_equal second_inviter, DeviseInvitable::Invitation.order(:id).last.invited_by
  end

  test 'an inviter exposes its sent invitations' do
    inviter = Admin.create!(email: 'admin@example.com', password: '123456789')

    User.invite!({ email: 'invited@example.com' }, inviter)

    assert_equal [DeviseInvitable::Invitation.last], inviter.sent_invitations.to_a
  end

  test 'deleting an inviter preserves sent invitations' do
    inviter = Admin.create!(email: 'admin@example.com', password: '123456789')
    User.invite!({ email: 'invited@example.com' }, inviter)
    invitation = DeviseInvitable::Invitation.last

    inviter.destroy!

    assert_predicate invitation.reload, :persisted?
    assert_nil invitation.invited_by
  end

  test 'a placeholder is inactive until an invitation is accepted' do
    User.create_resource_on_invitation = true

    user = User.invite!(email: 'placeholder@example.com')
    user.update_column(:confirmed_at, Time.now.utc)

    assert_predicate user, :invitation_pending?
    refute_predicate user, :active_for_authentication?
    assert_nil user.valid_password?('unknown')

    user.password = user.password_confirmation = '123456789'
    assert user.accept_invitation!
    refute_predicate user.reload, :invitation_pending?
    assert_predicate user, :active_for_authentication?
  end

  test 'resource attributes raise when placeholder creation is disabled' do
    User.create_resource_on_invitation = false

    error = assert_raises DeviseInvitable::ResourceAttributesRequirePlaceholderError do
      User.invite!(email: 'attributes@example.com', username: 'invited')
    end

    assert_includes error.message, 'username'
    assert_includes error.message, 'create_resource_on_invitation is disabled'
    assert_equal 0, DeviseInvitable::Invitation.count
  end

  test 'resource attributes assigned by a block raise when placeholder creation is disabled' do
    User.create_resource_on_invitation = false

    error = assert_raises DeviseInvitable::ResourceAttributesRequirePlaceholderError do
      User.invite!(email: 'attributes@example.com') do |invitable|
        invitable.username = 'invited'
      end
    end

    assert_includes error.message, 'username'
    assert_equal 0, DeviseInvitable::Invitation.count
  end

  test 'deferred invitations validate their invite keys' do
    User.create_resource_on_invitation = false

    invited = User.invite!(email: 'not-an-email')

    assert_includes invited.errors.details[:email], error: :invalid
    assert_equal 0, DeviseInvitable::Invitation.count
  end

  test 'legacy invitation data migration is idempotent' do
    skip unless DEVISE_ORM == :mongoid

    user = User.create!(email: 'legacy@example.com', password: '123456789')
    created_at = 1.day.ago
    user.update_columns(
      invitation_token: 'legacy-digest',
      invitation_created_at: created_at,
      invitation_sent_at: created_at,
      invited_by_type: 'User'
    )

    assert_equal 1, DeviseInvitable::Migrator.call(User)
    assert_equal 0, DeviseInvitable::Migrator.call(User)

    invitation = DeviseInvitable::Invitation.find_by!(invitation_token: 'legacy-digest')
    assert_equal user, invitation.invitable
    assert_equal({ 'email' => 'legacy@example.com' }, invitation.invite_key.to_h.stringify_keys)
    assert_equal created_at.to_i, invitation.resource_created_at.to_i
  end

  test 'legacy invitation migration processes multiple resources in a batch' do
    skip unless DEVISE_ORM == :mongoid

    first = User.create!(email: 'first-legacy@example.com', password: '123456789')
    second = User.create!(email: 'second-legacy@example.com', password: '123456789')
    created_at = 1.day.ago
    first.update_columns(invitation_token: 'first-legacy-digest', invitation_created_at: created_at)
    second.update_columns(invitation_token: 'second-legacy-digest', invitation_created_at: created_at)

    assert_equal 2, DeviseInvitable::Migrator.call(User)
    assert_equal 2, DeviseInvitable::Invitation.where(:invitable_id.in => [first.id, second.id]).count
    refute first.reload.attributes.key?('invitation_created_at')
    refute second.reload.attributes.key?('invitation_created_at')
  end
end
