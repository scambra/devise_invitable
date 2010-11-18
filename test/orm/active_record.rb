ActiveRecord::Migration.verbose = false
ActiveRecord::Base.logger = Logger.new(nil)

ActiveRecord::Schema.define(:version => 1) do
  create_table :users do |t|
    t.database_authenticatable :null => true
    t.string :username
    t.confirmable
    t.invitable
    t.encryptable
    
    t.timestamps
  end
end