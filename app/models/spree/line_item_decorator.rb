Spree::LineItem.class_eval do
  Spree::LineItem.class_eval do
    validates_with Spree::Stock::PosAvailabilityValidator, if: -> { order.is_pos? }
  end
  attr_accessor :is_pos
  define_method(:copy_price) do
    if variant
      self.cost_price = variant.cost_price if cost_price.nil?
      self.currency = variant.currency if currency.nil?
    end
    if is_pos == true
      price
    else
      self.price = variant.volume_price(quantity, order.user)
    end
  end
end
