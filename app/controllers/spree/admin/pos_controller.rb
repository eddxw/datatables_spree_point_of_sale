class Spree::Admin::PosController < Spree::Admin::BaseController
  before_action :load_order, :ensure_pos_order, :ensure_unpaid_order, except: :new
  helper_method :user_stock_locations
  before_action :load_variant, only: %i[add remove]
  before_action :ensure_active_store
  before_action :ensure_pos_shipping_method
  before_action :ensure_payment_method, only: :update_payment
  before_action :ensure_existing_user, only: :associate_user
  before_action :check_unpaid_pos_order, only: :new
  before_action :check_discount_request, only: :apply_discount
  before_action :load_line_item, only: %i[update_line_item_quantity apply_discount change_price change_garantia]

  before_action :clean_and_reload_order, only: :update_stock_location

  def new
    init_pos
    redirect_to admin_pos_show_order_path(number: @order.number)
  end

  def find
    respond_to do |format|
      format.html do
        init_search
        stock_location = @order.pos_shipment.stock_location
        @search = Spree::Variant.includes([:product]).available_at_stock_location(stock_location.id).ransack(params[:q])
        @variants = @search.result(distinct: true).page(params[:page]).per(PRODUCTS_PER_SEARCH_PAGE)
      end
      format.json do
        render json: VariantDatatable.new(params, user: spree_current_user,
                                                  stock_location: @order.pos_shipment.stock_location, order: @order)
      end
    end
  end

  def add
    @item = add_variant(@variant) if @variant.present?
    flash[:notice] = Spree.t(:product_added) if @item.errors.blank?
    flash[:error] = @item.errors.full_messages.to_sentence if @item.errors.present?
    respond_to do |format|
      format.html { redirect_to admin_pos_show_order_path(number: @order.number) }
      format.js {}
    end
  end

  def remove
    qty = @order.line_items.find_by(variant_id: @variant.id).quantity
    line_item = @order.contents.remove(@variant, qty, @order.pos_shipment)
    
    @item = line_item

    @order.assign_shipment_for_pos(spree_current_user) if @order.reload.pos_shipment.blank?
    flash.notice = line_item.quantity.zero? ? Spree.t(:product_removed) : Spree.t(:quantity_updated)
    respond_to do |format|
      format.html { redirect_to admin_pos_show_order_path(number: @order.number) }
      format.js {}
    end
  end

  def update_line_item_quantity
    @item.is_pos = false
    @item.quantity = params[:quantity]
    @item.save
    @order.update_totals
    @order.save

    flash.now[:notice] = Spree.t(:quantity_updated) if @item.errors.blank?
    flash.now[:error] = @item.errors.full_messages.to_sentence if @item.errors.present?
    respond_to do |format|
      format.html { redirect_to admin_pos_show_order_path(number: @order.number) }
      format.js {}
    end
  end

  def apply_discount
    @item.is_pos = true
    @item.price = @item.variant.price * (1.0 - @discount / 100.0)
    @item.save
    @order.update_totals
    @order.save
    flash.now[:error] = @item.errors.full_messages.to_sentence if @item.errors.present?
    respond_to do |format|
      format.html { redirect_to admin_pos_show_order_path(number: @order.number) }
      format.js {}
    end
  end

  def change_price
    @item.is_pos = true
    @item.price = params[:new_price]
    @item.save!
    @order.update_totals
    @order.save

    #flash.notice[:notice] = Spree.t(:price_changed) if @item.errors.blank?
    flash.now[:error] = @item.errors.full_messages.to_sentence if @item.errors.present?

    respond_to do |format|
      format.html { redirect_to admin_pos_show_order_path(number: @order.number) }
      format.js {}
    end
  end

  def change_garantia
    @item.garantia = params[:new_garantia]
    @item.save!
    @order.save
    flash[:error] = @item.errors.full_messages.to_sentence if @item.errors.present?

    respond_to do |format|
      format.html { redirect_to admin_pos_show_order_path(number: @order.number) }
      format.js {}
    end
  end

  def clean_order
    @order.try(:empty)
    @order.shipments.destroy_all
    @order.shipments.create_shipment_for_pos_order
    @order.save!
    redirect_to admin_pos_show_order_path(number: @order.number), notice: Spree.t(:remove_items)
  end

  def associate_user
    @user = @order.associate_user_for_pos(params[:email].present? ? params[:email] : params[:new_email])
    if @user.errors.present?
      add_error Spree.t(:add_user_failure, errors: @user.errors.full_messages.to_sentence)
    else
      @order.associate_user!(@user)
      @order.save!
      flash[:notice] = Spree.t(:add_user_success)
    end

    redirect_to admin_pos_show_order_path(number: @order.number)
  end

  def update_payment
    @payment_method_id = params[:payment_method_id]
    @payment = @order.save_payment_for_pos(params[:payment_method_id], params[:card_name])
    if @payment.errors.blank?
      print
    else
      add_error @payment.errors.full_messages.to_sentence
      redirect_to admin_pos_show_order_path(number: @order.number)
    end
  end

  def update_stock_location
    @order.shipments.first.destroy
    @order.save!
    @shipment = @order.pos_shipment
    @shipment.stock_location = user_stock_locations(spree_current_user).find_by(id: params[:stock_location_id])
    if @shipment.save
      flash[:notice] = "Ubicación: #{@shipment.stock_location.name}"
    else
      flash[:error] = @shipment.errors.full_messages.to_sentence
    end
    respond_to do |format|
      format.html { redirect_to admin_pos_show_order_path(number: @order.number) }
      format.js {}
    end
  end

  private

  def clean_and_reload_order
    @order.clean!(spree_current_user)
    load_order
  end

  def check_discount_request
    @discount = params[:discount].try(:to_f)
    redirect_to admin_pos_show_order_path(number: @order.number), flash: { error: Spree.t('pos_order.invalid_discount') } unless VALID_DISCOUNT_REGEX.match(params[:discount]) || @discount >= 100
  end

  def ensure_pos_order
    unless @order.is_pos?
      flash[:error] = Spree.t('pos_order.not_pos')
      render :show
    end
  end

  def ensure_unpaid_order
    if @order.paid?
      flash[:error] = Spree.t('pos_order.already_completed')
      render :show
    end
  end

  def load_line_item
    @item = @order.line_items.find_by(id: params[:line_item_id])
  end

  def check_unpaid_pos_order
    if spree_current_user.unpaid_pos_orders.present?
      add_error(Spree.t('pos_order.existing_order'))
      redirect_to admin_pos_show_order_path(number: spree_current_user.unpaid_pos_orders.first.number)
    end
  end

  def ensure_existing_user
    invalid_user_message = Spree.t('point_of_sale.user.not_found_email', email: params[:email]) if params[:email].present? && Spree::User.where(email: params[:email]).blank?
    invalid_user_message = Spree.t('point_of_sale.user.existing_user', email: params[:new_email]) if params[:new_email].present? && Spree::User.where(email: params[:new_email]).present?
    redirect_to admin_pos_show_order_path(number: @order.number), flash: { error: invalid_user_message } if invalid_user_message
  end

  def ensure_pos_shipping_method
    redirect_to root_path, flash: { error: Spree.t('pos_order.shipping_not_found') } unless Spree::ShippingMethod.find_by(name: SpreePos::Config[:pos_shipping])
  end

  def ensure_active_store
    redirect_to root_path, flash: { error: Spree.t('pos_order.active_store_not_found') } if user_stock_locations(spree_current_user).blank?
  end

  def load_order
    @order = Spree::Order.where(number: params[:number]).includes([{ line_items: [{ variant: [:default_price, { product: [:master] }] }] }, { adjustments: :adjustable }]).first
    redirect_to root_path, flash: { error: "No order found for -#{params[:number]}-" } unless @order
  end

  def load_variant
    @variant = Spree::Variant.find_by(id: params[:item])
    unless @variant
      flash[:error] = Spree.t('pos_order.variant_not_found')
      render :show
    end
  end

  def ensure_payment_method
    if Spree::PaymentMethod.where(id: params[:payment_method_id]).blank?
      flash[:error] = Spree.t('pos_order.payment_not_found')
      redirect_to admin_pos_show_order_path(number: @order.number)
    end
  end

  def init_pos
    @order = Spree::Order.new(state: 'complete', is_pos: true, completed_at: Time.current, payment_state: 'balance_due')
    @order.associate_user!(spree_current_user)
    spree_current_user.sales << @order
    @order.save!
    @order.assign_shipment_for_pos(spree_current_user)
    @order.shipments.first.stock_location = spree_current_user.stock_locations.first
    @order.save!
    session[:pos_order] = @order.number
  end

  def add_error(error_message)
    flash[:error] ||= []
    flash[:error] << error_message
  end

  def add_variant(var, quant = 1)
    line_item = @order.contents.add(var, quant, shipment: @order.pos_shipment)
    var.product.save
    line_item
  end

  def user_stock_locations(user)
    # use this code when stock managers implemented
    # @stock_location ||= (user.has_spree_role?('pos_admin') ? Spree::StockLocation.active.stores : user.stock_locations.active.store)
    # Spree::StockLocation.active.stores
    user.stock_locations
  end

  def init_search
    params[:q] ||= {}
    params[:q].merge!(meta_sort: 'product_name asc', deleted_at_null: '1', product_deleted_at_null: '1', published_at_not_null: '1')
    params[:q][:product_name_cont].try(:strip!)
  end

  def print
    @order.complete_via_pos
    @recibourl = SpreePos::Config[:pos_printing].sub('number', @order.number.to_s)
    redirect_to admin_pos_show_order_path(number: @order.number)
  end
end
