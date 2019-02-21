class AddNameToSpreeUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :spree_users, :complete_name, :string
  end
end
