ActiveRecord::Migration.verbose = false
ActiveRecord::Base.logger = Logger.new(nil)

if ActiveRecord::VERSION::MAJOR >= 7
  ActiveRecord::MigrationContext.new(
    File.expand_path('../../rails_app/db/migrate/', __FILE__)
  ).migrate
else # rails 6
  ActiveRecord::MigrationContext.new(
    File.expand_path('../../rails_app/db/migrate/', __FILE__),
    ActiveRecord::Base.connection.schema_migration
  ).migrate
end