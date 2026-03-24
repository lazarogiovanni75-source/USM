class WeeklyStrategyAnalysisJob < ApplicationJob
  queue_as :default

  def perform(user_id = nil)
    if user_id
      # Run for specific user
      user = User.find_by(id: user_id)
      process_user(user) if user
    else
      # Run for all active users (users with password set)
      User.where.not(password_digest: nil).find_each do |user|
        process_user(user)
      end
    end
  end

  private

  def process_user(user)
    return unless user.present?
    
    # Skip if user has no social accounts
    return unless user.social_accounts.any?
    
    # Skip if user has no password (OAuth-only users might not have social accounts set up)
    return if user.password_digest.nil?
    
    # Skip if user has no content activity (new user with no history)
    return unless user.contents.any? || user.scheduled_posts.any?
    
    begin
      analyzer = MarketingStrategyAnalyzerService.new(user)
      
      # Generate and save strategy to history
      history = analyzer.save_to_history(focus_area: 'comprehensive', generated_by: 'auto_weekly')
      
      if history
        Rails.logger.info "[WeeklyStrategyAnalysis] Generated strategy for user #{user.id}: Score #{history.overall_score}"
      else
        Rails.logger.warn "[WeeklyStrategyAnalysis] Failed to generate strategy for user #{user.id}"
      end
    rescue PostformeService::PostformeError => e
      # Skip users without Postforme connection - not an error
      Rails.logger.info "[WeeklyStrategyAnalysis] Skipping user #{user.id}: No Postforme connection"
    rescue StandardError => e
      Rails.logger.error "[WeeklyStrategyAnalysis] Error processing user #{user.id}: #{e.message}"
    end
  end
end
