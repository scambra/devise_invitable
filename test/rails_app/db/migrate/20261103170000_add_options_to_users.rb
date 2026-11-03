class AddOptionsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :options, :json
  end
end
