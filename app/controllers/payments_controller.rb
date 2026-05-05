class PaymentsController < ApplicationController
  before_action :authenticate_user!, except: [:webhook]
  before_action :set_payment, only: [:pay, :success, :failure]
  skip_before_action :verify_authenticity_token, only: [:webhook], raise: false

  def pay
    # Initialize Stripe payment for this payment record
    stripe_service = StripePaymentService.new(@payment, request)
    result = stripe_service.call

    if result[:success]
      @checkout_url = result[:checkout_session].url
      # Render turbo stream to redirect to Stripe checkout
      render formats: [:turbo_stream]
    else
      flash[:alert] = "Payment initialization failed: #{result[:error]}"
      redirect_to root_path
    end
  end

  def success
    # In development mode, sync payment status from Stripe
    # since webhooks might not be properly configured
    if @payment.processing?
      StripePaymentService.sync_payment_status(@payment)
      # Reload current_user to get fresh data (credits etc.) after payment processing
      current_user&.reload
    end

    unless @payment.paid?
      redirect_to root_path, alert: 'Payment was not paid. Please try again.'
      return
    end

    # Auto-verify user after successful payment
    # This ensures users must pay before getting full access
    @payment.user.update!(verified: true) if @payment.user.present?

    redirect_to root_path, notice: 'Payment successful! Your account is now verified.'
  end

  def failure
    redirect_to root_path, alert: 'Payment was canceled or failed. Please try again.'
  end

  # Stripe webhook endpoint
  def webhook
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = Rails.application.config.stripe[:webhook_secret]

    if endpoint_secret.blank?
      Rails.logger.error "[StripeWebhook] STRIPE_WEBHOOK_SECRET is not configured — rejecting request"
      return render json: { error: 'Webhook secret not configured' }, status: :internal_server_error
    end

    if sig_header.blank?
      Rails.logger.warn "[StripeWebhook] Request rejected: missing Stripe-Signature header"
      return render json: { error: 'Missing signature' }, status: :bad_request
    end

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
      StripePaymentService.process_webhook_event(event)
      render json: { status: 'success' }
    rescue JSON::ParserError => e
      Rails.logger.error "[StripeWebhook] Invalid JSON payload: #{e.message}"
      render json: { error: 'Invalid payload' }, status: :bad_request
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.warn "[StripeWebhook] Signature verification failed — possible spoofed request: #{e.message}"
      render json: { error: 'Invalid signature' }, status: :bad_request
    end
  end

  private

  def set_payment
    # Find payment and optionally verify user owns it
    @payment = Payment.find(params[:id])

    unless @payment.user == current_user || @payment.payable.try(:user) == current_user
      redirect_to root_path, alert: 'Access denied'
    end
  end
end
