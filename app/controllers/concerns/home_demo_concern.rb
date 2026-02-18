module HomeDemoConcern
  extend ActiveSupport::Concern

  included do
    # Handle demo page in both development and production
    skip_before_action :check_pending_migrations, if: -> { should_render_demo? }, raise: false
    before_action :check_demo_mode, only: [:index]
  end

  private

  def check_demo_mode
    if should_render_demo?
      @full_render = true
      @disable_error_tracking = true # Disable error tracking for demo page
      flash.now[:tips] = 'This is a quick preview version. The actual functionality is under development. Page will auto-refresh when ready'
      render 'shared/demo'
    else
      if !File.exist?(index_template_path)
        raise ActionController::MissingExactTemplate.new('no template', 'app/views/home/index.html.erb', [])
      end
    end
  end

  def should_render_demo?
    # Check for demo template - show demo page regardless of index.html.erb existence
    File.exist?(demo_template_path)
  end

  def demo_template_path
    Rails.root.join('app', 'views', 'shared', 'demo.html.erb')
  end

  def index_template_path
    Rails.root.join('app', 'views', controller_name, 'index.html.erb')
  end
end
