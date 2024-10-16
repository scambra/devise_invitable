ActiveRecord::Migration.verbose = false
ActiveRecord::Base.logger = Logger.new(nil)

ActiveRecord::MigrationContext.new(
  File.expand_path('../../rails_app/db/migrate/', __FILE__)
).migrate