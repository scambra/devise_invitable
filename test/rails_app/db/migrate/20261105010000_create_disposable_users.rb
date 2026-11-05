class CreateDisposableUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :disposable_users do |t|
      t.string :email
      t.string :encrypted_password
      t.timestamps
    end
  end
end
