Spree::Product.class_eval do
  delegate :ean, :"#{:ean}=", to: :find_or_build_master
  whitelisted_ransackable_associations << 'product_properties'
  whitelisted_ransackable_associations << 'variant_properties'
end
