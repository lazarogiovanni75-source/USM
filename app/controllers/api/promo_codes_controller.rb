module Api
  class PromoCodesController < ApplicationController
    skip_before_action :verify_authenticity_token
    
    def validate
      code = params[:code]&.strip
      
      if code.blank?
        render json: { valid: false, error: "Please enter a promo code" }
        return
      end

      promo = PromoCode.find_by(code: code.upcase)
      
      unless promo
        render json: { valid: false, error: "Invalid promo code" }
        return
      end

      unless promo.valid_for_use?
        render json: { valid: false, error: "This promo code has expired or reached its usage limit" }
        return
      end

      # Store promo data in session for use during checkout
      session[:promo_code] = promo.code
      session[:promo_discount] = {
        code: promo.code,
        discount_percent: promo.discount_percent,
        discount_amount: promo.discount_amount
      }.to_json

      render json: { 
        valid: true, 
        discount_percent: promo.discount_percent,
        discount_amount: promo.discount_amount,
        code: promo.code
      }
    rescue StandardError => e
      render json: { valid: false, error: "Error validating promo code" }
    end
  end
end
