class AddEanToSpreeVariants < ActiveRecord::Migration[5.2]
  def change
    add_column :spree_variants, :ean, :string
  end
end
