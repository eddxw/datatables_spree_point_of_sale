class Spree::Admin::BarbyInvoiceController < Spree::Admin::BaseController
  require 'barby'
  require 'barby/barcode/code_128'
  require 'barby/outputter/png_outputter'

  def show
    barcode = Barby::Code128B.new(params[:number])
    blob = Barby::PngOutputter.new(barcode).to_png(height: 50)
    respond_to do |format|
      format.html
      format.png do
        send_data blob, type: "image/png", disposition: "inline"
      end
    end
  end
end
