class ContentApprovalsController < ApplicationController
  skip_before_action :authenticate_user!

  before_action :find_draft, only: [:show, :update]

  # GET /content_approvals/:token?action_type=post_now|schedule|reject
  def show
    case params[:action_type]
    when "post_now"
      handle_post_now
    when "schedule"
      render :schedule_form
    when "reject"
      handle_reject
    else
      render :invalid
    end
  end

  # POST /content_approvals/:token (schedule form submits here)
  def update
    scheduled_time = DateTime.parse(params[:scheduled_for])
    @draft.approve!
    @draft.update!(scheduled_for: scheduled_time)

    PostContentJob.set(wait_until: scheduled_time).perform_later(@draft.id)

    render :scheduled
  rescue ArgumentError
    flash[:error] = "Invalid date. Please try again."
    render :schedule_form
  end

  private

  def find_draft
    @draft = DraftContent.find_by(approval_token: params[:token])
    render :invalid and return unless @draft

    if @draft.approved? || @draft.status == "posted"
      render :already_handled and return
    end
    
    if @draft.rejected?
      render :rejected and return
    end
  end

  def handle_post_now
    @draft.approve!
    PostContentJob.perform_later(@draft.id)
    render :posted
  end

  def handle_reject
    @draft.mark_rejected!
    render :rejected
  end
end
