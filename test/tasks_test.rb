# frozen_string_literal: true

require 'test_helper'
require 'rake'

class TasksTest < ActiveSupport::TestCase
  RAKE_APPLICATION = Rake::Application.new

  setup do
    @original_rake_application = Rake.application
    @original_model = ENV.delete('MODEL')
    Rake.application = RAKE_APPLICATION
    unless Rake::Task.task_defined?('devise_invitable:migrate_invitations')
      Rake::Task.define_task(:environment)
      load File.expand_path('../lib/tasks/devise_invitable_tasks.rake', __dir__)
    end
    Rake.application.tasks.each(&:reenable)
    DeviseInvitable::Invitation.delete_all
  end

  teardown do
    Rake.application = @original_rake_application
    ENV['MODEL'] = @original_model
  end

  test 'migration accepts a model argument and reports the migrated count' do
    DeviseInvitable::Migrator.expects(:call).with(User).returns(2)

    assert_output("Migrated 2 invitations for User\n") do
      Rake::Task['devise_invitable:migrate_invitations'].invoke('User')
    end
  end

  test 'migration accepts MODEL and reports a singular invitation' do
    ENV['MODEL'] = 'User'
    DeviseInvitable::Migrator.expects(:call).with(User).returns(1)

    assert_output("Migrated 1 invitation for User\n") do
      Rake::Task['devise_invitable:migrate_invitations'].invoke
    end
  end

  test 'migration argument takes precedence over MODEL' do
    ENV['MODEL'] = 'Admin'
    DeviseInvitable::Migrator.expects(:call).with(User).returns(0)

    assert_output("Migrated 0 invitations for User\n") do
      Rake::Task['devise_invitable:migrate_invitations'].invoke('User')
    end
  end

  test 'migration requires a model name' do
    DeviseInvitable::Migrator.expects(:call).never

    error = assert_raises(ArgumentError) do
      Rake::Task['devise_invitable:migrate_invitations'].invoke
    end

    assert_includes error.message, 'devise_invitable:migrate_invitations[User]'
  end

  test 'migration rejects an unknown model' do
    DeviseInvitable::Migrator.expects(:call).never

    assert_raises(NameError) do
      Rake::Task['devise_invitable:migrate_invitations'].invoke('MissingInvitableModel')
    end
  end

  test 'migration propagates failures without reporting success' do
    DeviseInvitable::Migrator.expects(:call).with(User).raises(ArgumentError, 'unsupported model')

    assert_output('') do
      error = assert_raises(ArgumentError) do
        Rake::Task['devise_invitable:migrate_invitations'].invoke('User')
      end
      assert_equal 'unsupported model', error.message
    end
  end

  test 'cleanup clears all terminal digests and preserves pending invitations' do
    pending = invitation_with_digest
    terminal = %i[invitation_accepted_at superseded_at revoked_at].map do |field|
      invitation_with_digest(field => Time.now.utc)
    end
    count = DeviseInvitable::Invitation.count

    assert_output("Cleared 3 terminal invitation digests\n") do
      Rake::Task['devise_invitable:clear_terminal_invitation_digests'].invoke
    end

    terminal.each { |invitation| assert_nil invitation.reload.invite_key_digest }
    assert_equal 'legacy-digest', pending.reload.invite_key_digest
    assert_equal count, DeviseInvitable::Invitation.count
  end

  test 'cleanup reports a singular invitation digest and can be repeated' do
    invitation = invitation_with_digest(revoked_at: Time.now.utc)
    task = Rake::Task['devise_invitable:clear_terminal_invitation_digests']

    2.times do
      task.reenable
      assert_output("Cleared 1 terminal invitation digest\n") { task.invoke }
      assert_nil invitation.reload.invite_key_digest
    end
  end

  test 'cleanup handles an empty invitation store' do
    assert_output("Cleared 0 terminal invitation digests\n") do
      Rake::Task['devise_invitable:clear_terminal_invitation_digests'].invoke
    end
  end

  private

  def invitation_with_digest(attributes = {})
    invitation = DeviseInvitable::Invitation.create!({invitable_type: 'User'}.merge(attributes))
    # Preserve a historical digest without triggering the model's automatic cleanup.
    # rubocop:disable Rails/SkipsModelValidations -- Set up historical data without automatic cleanup.
    DeviseInvitable::Invitation.where(id: invitation.id).update_all(invite_key_digest: 'legacy-digest')
    # rubocop:enable Rails/SkipsModelValidations
    invitation
  end
end
