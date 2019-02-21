class CreateSpreeUserStores < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_user_stores do |t|
      t.integer :user_id
      t.integer :stock_location_id
    end
  end
end