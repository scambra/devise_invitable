ActiveRecord::Migration.verbose = false
ActiveRecord::Base.logger = Logger.new(nil)

if defined? ActiveRecord::MigrationContext # rails >= 5.2
  ActiveRecord::MigrationContext.new(File.expand_path('../../rails_app/db/migrate/', __FILE__)).migrate
else
  ActiveRecord::Migrator.migrate(File.expand_path('../../rails_app/db/migrate/', __FILE__))
end
