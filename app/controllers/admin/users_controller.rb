module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:show, :verify, :unverify]

    def index
      @users = User.order(created_at: :desc)
                   .page(params[:page])
                   .per(10)

      # Filter by verified status
      if params[:verified].present?
        @users = @users.where(verified: params[:verified] == 'true')
      end

      # Search by name or email
      if params[:q].present?
        @users = @users.where("name ILIKE ? OR email ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
      end

      # Calculate statistics
      calculate_statistics
    end

    def show
      # View-only - users should be managed through the user-facing interface
    end

    def verify
      if @user.update(verified: true)
        redirect_to admin_users_path, notice: "User #{@user.email} has been verified."
      else
        redirect_to admin_users_path, alert: "Failed to verify user."
      end
    end

    def unverify
      if @user.update(verified: false)
        redirect_to admin_users_path, notice: "User #{@user.email} verification has been revoked."
      else
        redirect_to admin_users_path, alert: "Failed to revoke verification."
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def calculate_statistics
      # Today's new users
      @today_users_count = User.where('created_at >= ?', Time.current.beginning_of_day).count

      # This month's new users
      @this_month_users_count = User.where('created_at >= ?', Time.current.beginning_of_month).count

      # Active users (users with sessions in the last 7 days)
      @active_users_count = User.joins(:sessions)
                                .where('sessions.created_at >= ?', 7.days.ago)
                                .distinct
                                .count

      # Total users
      @total_users_count = User.count
    end
  end
end
