module Spree
  class UserStore < Spree::Base
    belongs_to :user
    belongs_to :stock_location
  end
end