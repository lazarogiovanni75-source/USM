module OnboardingTrackable
  extend ActiveSupport::Concern

  ONBOARDING_STEPS = {
    "connect_social_account" => {
      label: "Connect a social media account",
      description: "Connect at least one platform (Instagram, TikTok, LinkedIn, etc.)",
      path: "/social_account_connections",
      order: 1
    },
    "setup_brand_voice" => {
      label: "Set up your Brand Voice",
      description: "Train the AI to write in your unique style",
      path: "/brand_voice",
      order: 2
    },
    "generate_first_content" => {
      label: "Generate your first AI content",
      description: "Create your first post using the AI content generator",
      path: "/contents/new",
      order: 3
    },
    "create_first_campaign" => {
      label: "Create your first campaign",
      description: "Set up a multi-post campaign for maximum impact",
      path: "/campaigns/new",
      order: 4
    },
    "schedule_first_post" => {
      label: "Schedule your first post",
      description: "Schedule a post to go live automatically",
      path: "/scheduled_posts",
      order: 5
    },
    "setup_subscription" => {
      label: "Set up your subscription",
      description: "Choose a plan to unlock full features",
      path: "/subscription",
      order: 6
    }
  }.freeze

  included do
    def onboarding_steps_hash
      JSON.parse(onboarding_steps || '{}')
    end

    def complete_onboarding_step!(step_key)
      steps = onboarding_steps_hash
      steps[step_key] = { completed: true, completed_at: Time.current.iso8601 }
      update!(onboarding_steps: steps.to_json)
      check_onboarding_complete!
    end

    def onboarding_step_completed?(step_key)
      onboarding_steps_hash.dig(step_key, "completed") == true
    end

    def onboarding_progress
      completed = onboarding_steps_hash.count { |_, v| v["completed"] }
      total = ONBOARDING_STEPS.count
      { completed: completed, total: total, percentage: (completed.to_f / total * 100).round }
    end

    def onboarding_complete?
      onboarding_completed_at.present?
    end

    def next_onboarding_step
      ONBOARDING_STEPS
        .sort_by { |_, v| v[:order] }
        .find { |key, _| !onboarding_step_completed?(key) }
        &.first
    end

    def pending_onboarding_steps
      ONBOARDING_STEPS.reject { |key, _| onboarding_step_completed?(key) }
    end

    private

    def check_onboarding_complete!
      if onboarding_steps_hash.count { |_, v| v["completed"] } >= ONBOARDING_STEPS.count
        update!(onboarding_completed_at: Time.current)
      end
    end
  end
end
