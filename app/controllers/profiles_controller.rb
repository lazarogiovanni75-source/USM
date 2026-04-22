class ProfilesController < ApplicationController
  before_action :authenticate

  def show
    @user = current_user
  end

  def edit
    @user = current_user
    @brand_profile = BrandProfile.get_or_create_for(@user)
  end

  def update
    @user = current_user

    if @user.update(user_params)
      need_email_verification = @user.previous_changes.include?(:email)
      if need_email_verification
        send_email_verification
        additional_notice = "and sent a verification email to your new email address"
      end
      redirect_to profile_path, notice: "Profile updated #{additional_notice}"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update_brand_profile
    @brand_profile = BrandProfile.get_or_create_for(current_user)
    
    brand_params = params.require(:brand_profile).permit(
      :business_name, :industry, :website_url, :products_services, 
      :content_tone, :posting_topics, :topics_to_avoid
    )
    
    if @brand_profile.update(brand_params)
      redirect_to edit_profile_path, notice: "Brand profile updated successfully"
    else
      @user = current_user
      render :edit, status: :unprocessable_entity
    end
  end

  def edit_password
    @user = current_user
  end

  def update_password
    @user = current_user

    unless @user.authenticate(params[:user][:current_password])
      flash.now[:alert] = "Password not correct"
      render :edit_password, status: :unprocessable_entity
      return
    end

    if @user.update(password_params)
      redirect_to profile_path, notice: "Password updated"
    else
      render :edit_password, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def send_email_verification
    UserMailer.with(user: @user).email_verification.deliver_later
  end
end
