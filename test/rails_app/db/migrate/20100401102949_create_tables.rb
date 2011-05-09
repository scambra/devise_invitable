class CreateTables < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.database_authenticatable :null => true
      t.string :username
      t.confirmable
      t.invitable
      t.recoverable
      
      t.timestamps
    end
    create_table :admins do |t|
      t.database_authenticatable :null => true
    end
  end

  def self.down
    drop_table :users
  end
end
