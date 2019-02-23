class AddEanToVariants < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_variants, :ean, :string
  end
end
