# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_01_31_074824) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_oplogs", force: :cascade do |t|
    t.bigint "administrator_id", null: false
    t.string "action"
    t.string "resource_type"
    t.integer "resource_id"
    t.string "ip_address"
    t.text "user_agent"
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_admin_oplogs_on_action"
    t.index ["administrator_id"], name: "index_admin_oplogs_on_administrator_id"
    t.index ["created_at"], name: "index_admin_oplogs_on_created_at"
    t.index ["resource_type", "resource_id"], name: "index_admin_oplogs_on_resource_type_and_resource_id"
  end

  create_table "administrators", force: :cascade do |t|
    t.string "name", null: false
    t.string "password_digest"
    t.string "role", null: false
    t.boolean "first_login", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_administrators_on_name", unique: true
    t.index ["role"], name: "index_administrators_on_role"
  end

  create_table "ai_conversations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", default: "AI Chat"
    t.string "session_type", default: "general"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_type"], name: "index_ai_conversations_on_session_type"
    t.index ["user_id"], name: "index_ai_conversations_on_user_id"
  end

  create_table "ai_messages", force: :cascade do |t|
    t.bigint "ai_conversation_id", null: false
    t.string "role"
    t.text "content"
    t.integer "tokens_used"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_conversation_id"], name: "index_ai_messages_on_ai_conversation_id"
    t.index ["role"], name: "index_ai_messages_on_role"
  end

  create_table "ai_task_results", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "task_type", null: false
    t.text "summary"
    t.jsonb "result_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ai_task_results_on_created_at"
    t.index ["task_type"], name: "index_ai_task_results_on_task_type"
    t.index ["user_id"], name: "index_ai_task_results_on_user_id"
  end

  create_table "auto_response_triggers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "trigger_type", null: false
    t.string "response_type", null: false
    t.string "status", default: "active"
    t.text "conditions", default: [], array: true
    t.jsonb "config", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["response_type"], name: "index_auto_response_triggers_on_response_type"
    t.index ["status"], name: "index_auto_response_triggers_on_status"
    t.index ["trigger_type"], name: "index_auto_response_triggers_on_trigger_type"
    t.index ["user_id"], name: "index_auto_response_triggers_on_user_id"
  end

  create_table "auto_responses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "content_id", null: false
    t.bigint "auto_response_trigger_id"
    t.bigint "response_template_id"
    t.string "response_type", null: false
    t.string "status", default: "generated"
    t.text "ai_generated_text"
    t.datetime "sent_at"
    t.jsonb "response_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auto_response_trigger_id"], name: "index_auto_responses_on_auto_response_trigger_id"
    t.index ["content_id"], name: "index_auto_responses_on_content_id"
    t.index ["created_at"], name: "index_auto_responses_on_created_at"
    t.index ["response_template_id"], name: "index_auto_responses_on_response_template_id"
    t.index ["response_type"], name: "index_auto_responses_on_response_type"
    t.index ["status"], name: "index_auto_responses_on_status"
    t.index ["user_id"], name: "index_auto_responses_on_user_id"
  end

  create_table "automation_rules", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.string "trigger_type"
    t.string "action_type"
    t.json "conditions"
    t.json "actions"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_automation_rules_on_is_active"
    t.index ["user_id"], name: "index_automation_rules_on_user_id"
  end

  create_table "buffer_analytics", force: :cascade do |t|
    t.bigint "scheduled_post_id"
    t.string "buffer_update_id"
    t.integer "clicks"
    t.integer "impressions"
    t.integer "engagement"
    t.integer "reach"
    t.integer "shares"
    t.integer "likes"
    t.integer "comments"
    t.datetime "posted_at"
    t.datetime "synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scheduled_post_id"], name: "index_buffer_analytics_on_scheduled_post_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name", default: "Untitled"
    t.text "description"
    t.bigint "user_id"
    t.string "status", default: "draft"
    t.string "goal"
    t.string "campaign_type", default: "general"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_campaigns_on_user_id"
  end

  create_table "content_suggestions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "content_type"
    t.text "topic"
    t.text "suggestion"
    t.decimal "confidence"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "draft_content_id", null: false
    t.index ["draft_content_id"], name: "index_content_suggestions_on_draft_content_id"
    t.index ["status"], name: "index_content_suggestions_on_status"
    t.index ["user_id"], name: "index_content_suggestions_on_user_id"
  end

  create_table "content_template_variables", force: :cascade do |t|
    t.bigint "content_template_id", null: false
    t.string "variable_name", null: false
    t.text "variable_type", null: false
    t.text "default_value"
    t.text "placeholder_text"
    t.jsonb "validation_rules", default: "{}"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_template_id"], name: "index_content_template_variables_on_content_template_id"
    t.index ["variable_name"], name: "index_content_template_variables_on_variable_name"
    t.index ["variable_type"], name: "index_content_template_variables_on_variable_type"
  end

  create_table "content_templates", force: :cascade do |t|
    t.bigint "user_id"
    t.string "name"
    t.string "category"
    t.text "content"
    t.json "variables"
    t.string "platform"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.text "template_content"
    t.text "template_type"
    t.integer "usage_count", default: 0
    t.boolean "is_featured", default: false
    t.index ["is_active"], name: "index_content_templates_on_is_active"
    t.index ["user_id"], name: "index_content_templates_on_user_id"
  end

  create_table "contents", force: :cascade do |t|
    t.bigint "campaign_id"
    t.bigint "user_id"
    t.string "title", default: "Untitled"
    t.text "body"
    t.string "content_type", default: "text"
    t.string "platform", default: "instagram"
    t.text "media_urls"
    t.string "status", default: "draft"
    t.json "engagement_metrics", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_contents_on_campaign_id"
    t.index ["user_id"], name: "index_contents_on_user_id"
  end

  create_table "draft_contents", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.text "content"
    t.string "content_type"
    t.string "platform"
    t.string "status", default: "draft"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_draft_contents_on_status"
    t.index ["user_id"], name: "index_draft_contents_on_user_id"
  end

  create_table "engagement_metrics", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "content_id"
    t.string "metric_type"
    t.decimal "metric_value"
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_id"], name: "index_engagement_metrics_on_content_id"
    t.index ["metric_type"], name: "index_engagement_metrics_on_metric_type"
    t.index ["user_id"], name: "index_engagement_metrics_on_user_id"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at", where: "((retried_good_job_id IS NULL) AND (finished_at IS NOT NULL))"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "performance_metrics", force: :cascade do |t|
    t.bigint "scheduled_post_id"
    t.integer "impressions", default: 0
    t.integer "likes", default: 0
    t.integer "comments", default: 0
    t.integer "shares", default: 0
    t.decimal "engagement_rate", default: "0.0"
    t.integer "reach", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scheduled_post_id"], name: "index_performance_metrics_on_scheduled_post_id"
  end

  create_table "prompt_templates", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.string "category"
    t.text "prompt"
    t.text "description"
    t.json "variables"
    t.boolean "is_public", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_public"], name: "index_prompt_templates_on_is_public"
    t.index ["user_id"], name: "index_prompt_templates_on_user_id"
  end

  create_table "publish_queues", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "scheduled_post_id"
    t.bigint "content_id"
    t.text "platform", null: false
    t.jsonb "content_data", default: "{}", null: false
    t.datetime "scheduled_at", null: false
    t.integer "priority", default: 5, null: false
    t.text "status", default: "pending", null: false
    t.datetime "published_at"
    t.text "platform_post_id"
    t.text "error_message"
    t.integer "retry_count", default: 0
    t.datetime "next_retry_at"
    t.datetime "lock_expires_at"
    t.datetime "locked_at"
    t.jsonb "dependency_ids", default: "[]"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_id"], name: "index_publish_queues_on_content_id"
    t.index ["lock_expires_at"], name: "index_publish_queues_on_lock_expires_at"
    t.index ["platform"], name: "index_publish_queues_on_platform"
    t.index ["priority"], name: "index_publish_queues_on_priority"
    t.index ["scheduled_at"], name: "index_publish_queues_on_scheduled_at"
    t.index ["scheduled_post_id"], name: "index_publish_queues_on_scheduled_post_id"
    t.index ["status"], name: "index_publish_queues_on_status"
    t.index ["user_id"], name: "index_publish_queues_on_user_id"
  end

  create_table "response_templates", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "body", null: false
    t.string "category", default: "custom"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_response_templates_on_active"
    t.index ["category"], name: "index_response_templates_on_category"
    t.index ["user_id"], name: "index_response_templates_on_user_id"
  end

  create_table "scheduled_ai_tasks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "task_type", null: false
    t.string "schedule_type", null: false
    t.string "status", default: "active"
    t.datetime "next_run_at"
    t.jsonb "config", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["next_run_at"], name: "index_scheduled_ai_tasks_on_next_run_at"
    t.index ["status"], name: "index_scheduled_ai_tasks_on_status"
    t.index ["task_type"], name: "index_scheduled_ai_tasks_on_task_type"
    t.index ["user_id"], name: "index_scheduled_ai_tasks_on_user_id"
  end

  create_table "scheduled_posts", force: :cascade do |t|
    t.bigint "content_id"
    t.bigint "social_account_id"
    t.datetime "scheduled_at"
    t.string "status", default: "pending"
    t.datetime "posted_at"
    t.string "platform_post_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "webhook_status", default: "pending"
    t.text "webhook_error"
    t.integer "webhook_attempts", default: 0
    t.datetime "last_webhook_at"
    t.string "buffer_update_id"
    t.index ["content_id"], name: "index_scheduled_posts_on_content_id"
    t.index ["social_account_id"], name: "index_scheduled_posts_on_social_account_id"
  end

  create_table "scheduled_tasks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "task_type"
    t.json "payload"
    t.datetime "scheduled_at"
    t.datetime "executed_at"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_scheduled_tasks_on_status"
    t.index ["user_id"], name: "index_scheduled_tasks_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "social_accounts", force: :cascade do |t|
    t.bigint "user_id"
    t.string "platform", default: "instagram"
    t.string "account_name", default: "Untitled"
    t.string "account_url"
    t.string "access_token"
    t.boolean "is_connected", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "buffer_profile_id"
    t.string "buffer_access_token"
    t.index ["user_id"], name: "index_social_accounts_on_user_id"
  end

  create_table "task_executions", force: :cascade do |t|
    t.bigint "scheduled_ai_task_id", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "executed"
    t.jsonb "execution_data", default: {}
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_task_executions_on_created_at"
    t.index ["scheduled_ai_task_id"], name: "index_task_executions_on_scheduled_ai_task_id"
    t.index ["status"], name: "index_task_executions_on_status"
    t.index ["user_id"], name: "index_task_executions_on_user_id"
  end

  create_table "trend_analyses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "analysis_type"
    t.json "data"
    t.decimal "trend_score"
    t.text "insights"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_type"], name: "index_trend_analyses_on_analysis_type"
    t.index ["user_id"], name: "index_trend_analyses_on_user_id"
  end

  create_table "trigger_executions", force: :cascade do |t|
    t.bigint "auto_response_trigger_id", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "executed"
    t.jsonb "engagement_data", default: {}
    t.jsonb "response_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auto_response_trigger_id"], name: "index_trigger_executions_on_auto_response_trigger_id"
    t.index ["created_at"], name: "index_trigger_executions_on_created_at"
    t.index ["status"], name: "index_trigger_executions_on_status"
    t.index ["user_id"], name: "index_trigger_executions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email", null: false
    t.string "password_digest"
    t.boolean "verified", default: false, null: false
    t.string "provider"
    t.string "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role"
    t.string "subscription_plan"
    t.string "subscription_status"
    t.datetime "subscription_expires_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "voice_commands", force: :cascade do |t|
    t.bigint "user_id"
    t.text "command", default: "Untitled"
    t.text "transcribed_text"
    t.string "status", default: "pending"
    t.text "response_text"
    t.integer "campaign_id"
    t.decimal "ai_confidence", default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "command_type"
    t.text "error_message"
    t.index ["user_id"], name: "index_voice_commands_on_user_id"
  end

  create_table "voice_settings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "voice_id"
    t.string "tone", default: "neutral"
    t.decimal "speed", default: "1.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_voice_settings_on_user_id"
    t.index ["voice_id"], name: "index_voice_settings_on_voice_id"
  end

  create_table "zapier_webhooks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "webhook_url"
    t.string "event_type"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", null: false
    t.text "trigger_events", default: [], array: true
    t.jsonb "config", default: {}
    t.string "endpoint_id"
    t.string "status", default: "active"
    t.index ["endpoint_id"], name: "index_zapier_webhooks_on_endpoint_id", unique: true
    t.index ["is_active"], name: "index_zapier_webhooks_on_is_active"
    t.index ["status"], name: "index_zapier_webhooks_on_status"
    t.index ["trigger_events"], name: "index_zapier_webhooks_on_trigger_events", using: :gin
    t.index ["user_id"], name: "index_zapier_webhooks_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_oplogs", "administrators"
  add_foreign_key "ai_task_results", "users"
  add_foreign_key "auto_response_triggers", "users"
  add_foreign_key "auto_responses", "auto_response_triggers"
  add_foreign_key "auto_responses", "contents"
  add_foreign_key "auto_responses", "response_templates"
  add_foreign_key "auto_responses", "users"
  add_foreign_key "content_suggestions", "draft_contents"
  add_foreign_key "content_template_variables", "content_templates"
  add_foreign_key "publish_queues", "users"
  add_foreign_key "response_templates", "users"
  add_foreign_key "scheduled_ai_tasks", "users"
  add_foreign_key "scheduled_posts", "users", name: "scheduled_posts_user_id_fkey"
  add_foreign_key "sessions", "users"
  add_foreign_key "task_executions", "scheduled_ai_tasks"
  add_foreign_key "task_executions", "users"
  add_foreign_key "trigger_executions", "auto_response_triggers"
  add_foreign_key "trigger_executions", "users"
end
