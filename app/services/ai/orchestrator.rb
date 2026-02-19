# frozen_string_literal: true

module Ai
  class Orchestrator
    MAX_TASKS_PER_CAMPAIGN = 200
    MAX_ITERATIONS = 50
    TASK_TIMEOUT_SECONDS = 120
    OPTIMIZE_EVERY_POSTS = 5
    OPTIMIZE_EVERY_HOURS = 24
    OPTIMIZE_COOLDOWN_HOURS = 12
    FAILURE_RATE_THRESHOLD = 0.30  # 30% failure rate triggers pause
    MAX_OPTIMIZATION_CYCLES = 10

    def self.plan_campaign(campaign)
      campaign.update!(status: :planning, started_at: Time.current)

      # Initialize campaign context
      context = build_campaign_context(campaign)

      # Ask agent what to do first
      first_action = ask_agent(campaign.user, campaign, context)

      if first_action[:tool_name]
        # Create first task from agent's decision
        create_task_from_action(campaign, first_action)
        campaign.update!(status: :running)

        # Enqueue the task
        ExecuteTaskJob.perform_later(campaign.tasks.last.id)
      else
        # No tool selected - complete the campaign with message
        campaign.update!(
          status: :completed,
          completed_at: Time.current,
          strategy: (campaign.strategy || {}).merge(final_message: first_action[:content])
        )
      end

    rescue => e
      Rails.logger.error "[Orchestrator] Failed to plan campaign #{campaign.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      campaign.fail!
    end

    # Continue campaign after a task completes
    def self.continue_campaign(campaign)
      return unless campaign.running?

      # Guardrails check
      if campaign.tasks.count >= MAX_TASKS_PER_CAMPAIGN
        Rails.logger.warn "[Orchestrator] Campaign #{campaign.id} reached max tasks limit"
        campaign.update!(status: :completed, completed_at: Time.current)
        return
      end

      # Check if we have too many failed tasks
      failed_count = campaign.tasks.failed.count
      if failed_count > campaign.tasks.count * 0.5
        Rails.logger.warn "[Orchestrator] Campaign #{campaign.id} has too many failed tasks"
        campaign.fail!
        return
      end

      # Check for stop conditions first
      if should_stop?(campaign)
        Rails.logger.info "[Orchestrator] Campaign #{campaign.id} stopping - performance decline detected"
        campaign.update!(status: :completed, completed_at: Time.current)
        return
      end

      # Check hard limits and pause if exceeded
      if check_hard_limits(campaign)
        Rails.logger.warn "[Orchestrator] Campaign #{campaign.id} paused - hard limit exceeded"
        campaign.mark_paused!
        return
      end

      # Check failure rate and pause if too high
      if check_failure_rate?(campaign)
        Rails.logger.warn "[Orchestrator] Campaign #{campaign.id} paused - high failure rate"
        campaign.mark_paused!
        return
      end

      # Check if optimization is needed
      if should_optimize?(campaign)
        # Check safe_mode - skip optimization in safe mode
        unless campaign.safe_mode?
          optimize_campaign(campaign)
        else
          Rails.logger.debug "[Orchestrator] Campaign #{campaign.id} in safe_mode - skipping optimization"
        end
      end

      # Build updated context
      context = build_campaign_context(campaign)

      # Ask agent what to do next
      action = ask_agent(campaign.user, campaign, context)

      if action[:tool_name]
        # Create next task
        task = create_task_from_action(campaign, action)

        # Execute immediately (or enqueue)
        ExecuteTaskJob.perform_later(task.id)
      else
        # No more actions - campaign complete
        Rails.logger.info "[Orchestrator] Campaign #{campaign.id} completed - no more actions"
        campaign.update!(
          status: :completed,
          completed_at: Time.current,
          strategy: (campaign.strategy || {}).merge(final_message: action[:content])
        )
      end

    rescue => e
      Rails.logger.error "[Orchestrator] Continue campaign #{campaign.id} failed: #{e.message}"
      campaign.fail! if campaign.running?
    end

    # Check if campaign should stop due to performance decline
    def self.should_stop?(campaign)
      return false unless campaign.consecutive_decline_cycles.to_i >= 3

      Rails.logger.warn "[Orchestrator] Campaign #{campaign.id} stopping - 3 consecutive decline cycles"
      true
    end

    # Check if hard limits are exceeded
    def self.check_hard_limits(campaign)
      limit_check = UsageTracker.check_limits(campaign)
      return false unless limit_check[:exceeded]

      Rails.logger.warn "[Orchestrator] Campaign #{campaign.id} limits exceeded: #{limit_check[:reasons].join(', ')}"
      true
    end

    # Check if failure rate exceeds threshold
    def self.check_failure_rate?(campaign)
      total = campaign.tasks.count
      return false if total.zero?

      failed = campaign.tasks.failed.count
      rate = failed.to_f / total

      if rate >= FAILURE_RATE_THRESHOLD
        Rails.logger.warn "[Orchestrator] Campaign #{campaign.id} failure rate #{rate.round(2)}% exceeds #{FAILURE_RATE_THRESHOLD * 100}%"
        campaign.increment!(:failure_count)
        return true
      end

      false
    end

    # Check if optimization should be triggered
    def self.should_optimize?(campaign)
      # Every 5 published posts
      return true if campaign.published_posts_count.to_i > 0 &&
                     campaign.published_posts_count.to_i % OPTIMIZE_EVERY_POSTS == 0

      # Every 24 hours since last optimization
      if campaign.last_optimized_at.present?
        hours_since = (Time.current - campaign.last_optimized_at) / 3600
        return true if hours_since >= OPTIMIZE_EVERY_HOURS
      elsif campaign.started_at.present?
        # First optimization - check if 24 hours since start
        hours_since = (Time.current - campaign.started_at) / 3600
        return true if hours_since >= OPTIMIZE_EVERY_HOURS
      end

      false
    end

    # Optimize campaign based on performance metrics
    def self.optimize_campaign(campaign)
      Rails.logger.info "[Orchestrator] Optimizing campaign #{campaign.id}"

      # Check max optimization cycles
      optimization_count = campaign.strategy&.dig('optimization_cycle_count') || 0
      if optimization_count >= MAX_OPTIMIZATION_CYCLES
        Rails.logger.warn "[Orchestrator] Campaign #{campaign.id} reached max optimization cycles"
        return
      end

      # Check cooldown
      if campaign.last_optimized_at.present?
        hours_since = (Time.current - campaign.last_optimized_at) / 3600
        if hours_since < OPTIMIZE_COOLDOWN_HOURS
          Rails.logger.debug "[Orchestrator] Optimization in cooldown, skipping"
          return
        end
      end

      # Get current and previous metrics for comparison
      current_metrics = Analytics::CampaignMetricsAggregator.call(campaign)
      previous_engagement = campaign.strategy&.dig('last_engagement_rate') || 0
      current_engagement = current_metrics[:avg_engagement_rate] || 0

      # Track decline cycles
      if current_engagement < previous_engagement && previous_engagement > 0
        campaign.increment!(:consecutive_decline_cycles)
      else
        campaign.update!(consecutive_decline_cycles: 0)
      end

      # Store current metrics for next comparison
      campaign.update!(
        last_optimized_at: Time.current,
        strategy: (campaign.strategy || {}).merge(
          'last_engagement_rate' => current_engagement,
          'optimization_cycle_count' => optimization_count + 1
        )
      )

      # Ask agent for optimization recommendations
      agent = Ai::Agent.new(user: campaign.user, campaign: campaign)

      prompt = build_optimization_prompt(campaign, current_metrics)

      begin
        result = agent.call(prompt: prompt, allow_plain_text: true)

        if result[:tool_name]
          # Execute the optimization action
          task = create_task_from_action(campaign, result)
          ExecuteTaskJob.perform_later(task.id)
          Rails.logger.info "[Orchestrator] Optimization task created: #{result[:tool_name]}"
        end
      rescue => e
        Rails.logger.warn "[Orchestrator] Optimization agent call failed: #{e.message}"
      end
    end

    def self.build_optimization_prompt(campaign, metrics)
      <<~PROMPT
        Campaign: #{campaign.name}
        Goal: #{campaign.goal}

        Current Performance:
        - Total posts: #{metrics[:total_posts]}
        - Published posts: #{metrics[:published_posts]}
        - Total impressions: #{metrics[:total_impressions]}
        - Average engagement rate: #{metrics[:avg_engagement_rate]}%
        - Top performing post engagement: #{metrics[:top_posts]&.first&.dig(:engagement_rate) || 'N/A'}%
        - Worst performing post engagement: #{metrics[:worst_posts]&.first&.dig(:engagement_rate) || 'N/A'}%

        Platform breakdown:
        #{metrics[:platform_breakdown].map { |p| "- #{p[:platform]}: #{p[:avg_engagement_rate]}% engagement" }.join("\n")}

        Current strategy: #{campaign.strategy.inspect}

        Based on this performance data, what should we adjust?

        Available tools:
        - adjust_strategy: Change tone, frequency, or hashtags
        - test_new_format: Test new content formats (video, carousel, story)
        - analyze_performance: Get more detailed metrics
        - generate_post: Create new content with adjusted strategy

        IMPORTANT: Choose ONE action to optimize performance. Consider:
        - If engagement is declining, try changing tone or hashtags
        - If one platform performs better, focus there
        - If a format works well, test variations of it
        - If engagement is very low, try a completely different approach
      PROMPT
    end

    # Get next action from agent
    def self.ask_agent(user, campaign, context)
      prompt = build_continuation_prompt(campaign, context)

      agent = Ai::Agent.new(user: user, campaign: campaign)

      # This will raise if no tool is selected (as required)
      result = agent.call(prompt: prompt, allow_plain_text: true)

      Rails.logger.info "[Orchestrator] Agent action: #{result.inspect}"

      result
    end

    def self.build_campaign_context(campaign)
      {
        campaign_name: campaign.name,
        goal: campaign.goal,
        platforms: campaign.platforms || [],
        content_pillars: campaign.content_pillars || [],
        hashtags: campaign.hashtag_set || [],
        target_audience: campaign.target_audience,
        tasks_completed: campaign.tasks.done.count,
        tasks_failed: campaign.tasks.failed.count,
        tasks_pending: campaign.tasks.pending.count,
        total_posts_created: campaign.contents.count,
        scheduled_posts: campaign.scheduled_posts.count,
        usage: UsageTracker.current_usage(campaign),
        safe_mode: campaign.safe_mode?,
        recent_tasks: campaign.tasks.order(created_at: :desc).limit(5).map { |t|
          { tool_name: t.tool_name, status: t.status, result: t.result&.first(100) }
        }
      }
    end

    def self.build_continuation_prompt(campaign, context)
      <<~PROMPT
        Campaign: #{campaign.name}
        Goal: #{campaign.goal}
        Platforms: #{context[:platforms].join(', ')}

        Progress:
        - Tasks completed: #{context[:tasks_completed]}
        - Tasks failed: #{context[:tasks_failed]}
        - Posts created: #{context[:total_posts_created]}
        - Scheduled posts: #{context[:scheduled_posts]}

        Current Usage:
        - Cost: $#{context[:usage][:estimated_cost]}
        - Images generated: #{context[:usage][:images_generated]}
        - Posts published: #{context[:usage][:posts_published]}
        - LLM tokens: #{context[:usage][:llm_tokens]}

        Recent actions:
        #{context[:recent_tasks].map { |t| "- #{t[:tool_name]}: #{t[:status]}" }.join("\n")}

        Based on the campaign goal and progress, what should happen next?

        Available tools:
        - generate_post: Create a new social media post
        - generate_image: Generate an AI image for posts
        - schedule_post: Schedule a post for publishing
        - analyze_performance: Check how posts are performing
        - complete_campaign: Mark campaign as done

        If the campaign goals are met or no more actions are needed, use complete_campaign.
        Otherwise, use generate_post, generate_image, or schedule_post to continue.

        IMPORTANT: You MUST call a tool. Do not respond with plain text.
      PROMPT
    end

    def self.create_task_from_action(campaign, action)
      campaign.tasks.create!(
        tool_name: action[:tool_name],
        parameters: action[:parameters] || {},
        status: :pending,
        priority: campaign.tasks.count
      )
    end

    # Legacy methods for backward compatibility
    def self.generate_strategy(campaign)
      context = build_campaign_context(campaign)
      { "context" => context, "posts" => [] }
    end

    def self.create_tasks_from_strategy(campaign)
      # No longer needed - tasks are created dynamically
    end

    def self.enqueue_tasks(campaign)
      campaign.tasks.pending.find_each do |task|
        ExecuteTaskJob.perform_later(task.id)
      end
    end
  end
end
