class AddCardNameToSpreePayments < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_payments, :card_name, :string
  end
end
