Spree::Product.class_eval do
  whitelisted_ransackable_associations << 'product_properties'
  whitelisted_ransackable_associations << 'variant_properties'
end
