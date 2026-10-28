namespace :devise_invitable do
  desc 'Move legacy invitation fields into devise_invitations (MODEL=User also supported)'
  task :migrate_invitations, [:model] => :environment do |_task, args|
    model_name = args[:model] || ENV['MODEL']
    raise ArgumentError, 'Pass a model name: rake devise_invitable:migrate_invitations[User]' if model_name.blank?

    count = DeviseInvitable::Migrator.call(model_name.constantize)
    puts "Migrated #{count} invitation#{'s' unless count == 1} for #{model_name}"
  end
end
