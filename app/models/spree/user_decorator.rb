Spree::User.class_eval do
  has_many :user_stores
  has_many :stock_locations, through: :user_stores
  has_many :sales, class_name: 'Spree::Order', foreign_key: 'salesman_id'

  validates :complete_name, length: { minimum: 2 }, allow_blank: true

  def unpaid_pos_orders
    orders.unpaid_pos_order
  end

  def self.create_with_random_password(email)
    create(email: email, password: RANDOM_PASS_REGEX.sample(8).join)
  end
end
