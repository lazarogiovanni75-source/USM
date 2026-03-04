class Admin::SiteSettingsController < Admin::BaseController
  before_action :set_site_setting, only: [:show, :edit, :update, :destroy]

  def index
    @site_settings = SiteSetting.page(params[:page]).per(10)
  end

  def show
  end

  def new
    @site_setting = SiteSetting.new
  end

  def create
    @site_setting = SiteSetting.new(site_setting_params)

    if @site_setting.save
      redirect_to admin_site_setting_path(@site_setting), notice: 'Site setting was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @site_setting.update(site_setting_params)
      redirect_to admin_site_setting_path(@site_setting), notice: 'Site setting was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @site_setting.destroy
    redirect_to admin_site_settings_path, notice: 'Site setting was successfully deleted.'
  end

  private

  def set_site_setting
    @site_setting = SiteSetting.find(params[:id])
  end

  def site_setting_params
    params.require(:site_setting).permit(:key, :value)
  end
end
