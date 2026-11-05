namespace :devise_invitable do
  desc 'Move legacy invitation fields into devise_invitations (MODEL=User also supported)'
  task :migrate_invitations, [:model] => :environment do |_task, args|
    model_name = args[:model] || ENV['MODEL']
    raise ArgumentError, 'Pass a model name: rake devise_invitable:migrate_invitations[User]' if model_name.blank?

    count = DeviseInvitable::Migrator.call(model_name.constantize)
    puts "Migrated #{count} invitation#{'s' unless count == 1} for #{model_name}"
  end

  desc 'Clear invite-key digests from accepted, superseded, and revoked invitations'
  task clear_terminal_invitation_digests: :environment do
    terminal_invitations = DeviseInvitable::Invitation.terminal
    count = terminal_invitations.count
    terminal_invitations.update_all(invite_key_digest: nil)
    puts "Cleared #{count} terminal invitation digest#{'s' unless count == 1}"
  end
end
