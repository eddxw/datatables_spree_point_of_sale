class AddDeliveredAtAndCanceledAtToSpreeShipments < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_shipments, :delivered_at, :datetime
    add_column :spree_shipments, :canceled_at, :datetime
  end
end
