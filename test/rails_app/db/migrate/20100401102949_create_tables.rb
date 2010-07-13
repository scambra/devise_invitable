class CreateTables < ActiveRecord::Migration
  def self.up
    create_table :users, :force => true do |t|
      t.database_authenticatable :null => false

      t.string :email
      t.string :name
      t.confirmable
      t.invitable

      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end
