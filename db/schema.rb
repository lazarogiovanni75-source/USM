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

ActiveRecord::Schema[7.2].define(version: 2026_04_05_204603) do
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
    t.jsonb "context", default: {}
    t.jsonb "memory_summary", default: {}
    t.jsonb "session_metadata", default: {}
    t.boolean "archived", default: false
    t.datetime "archived_at"
    t.index ["archived"], name: "index_ai_conversations_on_archived"
    t.index ["created_at"], name: "index_ai_conversations_on_created_at"
    t.index ["session_type"], name: "index_ai_conversations_on_session_type"
    t.index ["user_id"], name: "index_ai_conversations_on_user_id"
  end

  create_table "ai_generated_contents", force: :cascade do |t|
    t.string "topic", null: false
    t.string "brand_voice", default: "professional"
    t.string "platform", null: false
    t.string "content_type", default: "caption"
    t.text "caption"
    t.text "blog_post"
    t.text "ad_copy"
    t.text "hashtags"
    t.text "thread_story"
    t.text "email_marketing"
    t.text "additional_context"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "custom_system_prompt"
    t.string "output_format", default: "short_form"
    t.boolean "is_edited", default: false
    t.index ["content_type"], name: "index_ai_generated_contents_on_content_type"
    t.index ["is_edited"], name: "index_ai_generated_contents_on_is_edited"
    t.index ["output_format"], name: "index_ai_generated_contents_on_output_format"
    t.index ["platform"], name: "index_ai_generated_contents_on_platform"
    t.index ["user_id", "created_at"], name: "index_ai_generated_contents_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_ai_generated_contents_on_user_id"
  end

  create_table "ai_messages", force: :cascade do |t|
    t.bigint "ai_conversation_id", null: false
    t.string "role"
    t.text "content"
    t.integer "tokens_used"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "message_type", default: "text"
    t.jsonb "metadata", default: {}
    t.index ["ai_conversation_id"], name: "index_ai_messages_on_ai_conversation_id"
    t.index ["created_at"], name: "index_ai_messages_on_created_at"
    t.index ["id"], name: "index_ai_messages_on_id", unique: true
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

  create_table "assistant_conversations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "messages", default: "[]"
    t.string "current_page"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_assistant_conversations_on_user_id"
  end

  create_table "audit_executions", force: :cascade do |t|
    t.bigint "user_id"
    t.string "tool_name"
    t.text "parameters"
    t.string "status"
    t.boolean "approved"
    t.datetime "executed_at"
    t.string "session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["executed_at"], name: "index_audit_executions_on_executed_at"
    t.index ["session_id"], name: "index_audit_executions_on_session_id"
    t.index ["status"], name: "index_audit_executions_on_status"
    t.index ["tool_name"], name: "index_audit_executions_on_tool_name"
    t.index ["user_id"], name: "index_audit_executions_on_user_id"
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

  create_table "automation_rule_executions", force: :cascade do |t|
    t.bigint "automation_rule_id", null: false
    t.jsonb "trigger_data", default: {}
    t.string "status", default: "pending"
    t.jsonb "execution_details", default: {}
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["automation_rule_id"], name: "index_automation_rule_executions_on_automation_rule_id"
    t.index ["created_at"], name: "index_automation_rule_executions_on_created_at"
    t.index ["status"], name: "index_automation_rule_executions_on_status"
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

  create_table "campaign_tasks", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.string "tool_name"
    t.jsonb "parameters", default: {}
    t.integer "status", default: 0, null: false
    t.text "result"
    t.text "error_message"
    t.integer "priority", default: 0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "retry_count", default: 0
    t.text "last_error"
    t.index ["campaign_id"], name: "index_campaign_tasks_on_campaign_id"
    t.index ["status"], name: "index_campaign_tasks_on_status"
  end

  create_table "campaign_templates", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "duration_days"
    t.jsonb "structure"
    t.boolean "is_active"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "campaign_usages", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.integer "llm_tokens", default: 0
    t.integer "images_generated", default: 0
    t.integer "posts_published", default: 0
    t.integer "api_calls", default: 0
    t.decimal "estimated_cost", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "videos_generated", default: 0
    t.index ["campaign_id"], name: "index_campaign_usages_on_campaign_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name", default: "Untitled"
    t.text "description"
    t.bigint "user_id"
    t.integer "status", default: 0
    t.string "goal"
    t.string "campaign_type", default: "general"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "start_date"
    t.date "end_date"
    t.decimal "budget", precision: 10, scale: 2
    t.text "target_audience"
    t.text "platforms"
    t.integer "content_count"
    t.text "hashtag_set"
    t.text "mentions"
    t.text "content_pillars"
    t.decimal "goal_value", precision: 10, scale: 2
    t.text "kpis"
    t.json "success_metrics"
    t.json "budget_allocation"
    t.text "brand_guidelines"
    t.text "competitors"
    t.text "influencer_targets"
    t.text "key_messages"
    t.jsonb "strategy", default: {}
    t.datetime "started_at"
    t.datetime "completed_at"
    t.boolean "safe_mode", default: true
    t.integer "failure_count", default: 0
    t.bigint "client_id"
    t.datetime "last_optimized_at"
    t.integer "consecutive_decline_cycles", default: 0
    t.integer "published_posts_count", default: 0
    t.integer "video_count", default: 2
    t.integer "image_count", default: 3
    t.index ["client_id"], name: "index_campaigns_on_client_id"
    t.index ["status"], name: "index_campaigns_on_status"
    t.index ["strategy"], name: "index_campaigns_on_strategy", using: :gin
    t.index ["user_id"], name: "index_campaigns_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "name", null: false
    t.string "contact_name"
    t.string "email"
    t.string "phone"
    t.text "address"
    t.string "status", default: "active", null: false
    t.string "plan", default: "basic"
    t.decimal "monthly_budget", precision: 10, scale: 2
    t.text "notes"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "agency_user_id"
    t.index ["agency_user_id"], name: "index_clients_on_agency_user_id"
    t.index ["status"], name: "index_clients_on_status"
    t.index ["user_id"], name: "index_clients_on_user_id"
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
    t.string "media_url"
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
    t.string "media_url"
    t.jsonb "metadata", default: {}
    t.string "approval_token"
    t.datetime "scheduled_for"
    t.string "postforme_post_id"
    t.datetime "posted_at"
    t.text "error_message"
    t.string "quality_tier", default: "standard"
    t.integer "credit_cost", default: 1
    t.index ["approval_token"], name: "index_draft_contents_on_approval_token", unique: true
    t.index ["postforme_post_id"], name: "index_draft_contents_on_postforme_post_id"
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

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id"
    t.decimal "total", default: "0.0"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.string "payable_type", null: false
    t.bigint "payable_id", null: false
    t.bigint "user_id"
    t.decimal "amount"
    t.string "currency", default: "usd"
    t.string "status", default: "pending"
    t.string "stripe_payment_intent_id"
    t.string "stripe_checkout_session_id"
    t.string "payment_method"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payable_type", "payable_id"], name: "index_payments_on_payable"
    t.index ["user_id"], name: "index_payments_on_user_id"
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
    t.integer "views", default: 0
    t.index ["scheduled_post_id"], name: "index_performance_metrics_on_scheduled_post_id"
  end

  create_table "post_analytics", force: :cascade do |t|
    t.bigint "scheduled_post_id", null: false
    t.string "postforme_post_id"
    t.integer "likes", default: 0
    t.integer "comments", default: 0
    t.integer "shares", default: 0
    t.integer "saves", default: 0
    t.integer "clicks", default: 0
    t.integer "impressions", default: 0
    t.integer "reach", default: 0
    t.integer "views", default: 0
    t.decimal "engagement_rate", precision: 5, scale: 2, default: "0.0"
    t.json "raw_data", default: {}
    t.datetime "fetched_at"
    t.datetime "posted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fetched_at"], name: "index_post_analytics_on_fetched_at"
    t.index ["postforme_post_id"], name: "index_post_analytics_on_postforme_post_id"
    t.index ["scheduled_post_id"], name: "index_post_analytics_on_scheduled_post_id"
  end

  create_table "post_metrics", force: :cascade do |t|
    t.string "post_type", null: false
    t.bigint "post_id", null: false
    t.string "platform"
    t.bigint "social_account_id"
    t.string "platform_post_id"
    t.integer "impressions", default: 0
    t.integer "likes", default: 0
    t.integer "comments", default: 0
    t.integer "shares", default: 0
    t.integer "saves", default: 0
    t.integer "clicks", default: 0
    t.float "engagement_rate", default: 0.0
    t.float "click_through_rate", default: 0.0
    t.jsonb "raw_metrics", default: {}
    t.datetime "collected_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collected_at"], name: "index_post_metrics_on_collected_at"
    t.index ["platform_post_id"], name: "index_post_metrics_on_platform_post_id"
    t.index ["post_type", "post_id"], name: "index_post_metrics_on_post"
    t.index ["post_type", "post_id"], name: "index_post_metrics_on_post_type_and_post_id"
    t.index ["social_account_id"], name: "index_post_metrics_on_social_account_id"
  end

  create_table "postforme_analytics", force: :cascade do |t|
    t.bigint "scheduled_post_id", null: false
    t.string "postforme_post_id"
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
    t.index ["postforme_post_id"], name: "index_postforme_analytics_on_postforme_post_id"
    t.index ["scheduled_post_id"], name: "index_postforme_analytics_on_scheduled_post_id"
  end

  create_table "promo_codes", force: :cascade do |t|
    t.string "code"
    t.integer "discount_percent", default: 0
    t.integer "discount_amount", default: 0
    t.boolean "is_active", default: true
    t.datetime "expires_at"
    t.integer "max_uses"
    t.integer "use_count", default: 0
    t.string "+"
    t.string "migration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.string "postforme_post_id"
    t.text "internal_note"
    t.text "error_message"
    t.string "image_url"
    t.string "video_url"
    t.string "asset_url"
    t.jsonb "target_platforms"
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

  create_table "site_settings", force: :cascade do |t|
    t.string "key"
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.string "postforme_api_key"
    t.string "postforme_profile_id"
    t.integer "likes"
    t.integer "views"
    t.integer "engagement"
    t.integer "shares"
    t.integer "followers"
    t.integer "new_followers"
    t.integer "unfollowers"
    t.integer "messages"
    t.string "oauth_access_token"
    t.string "oauth_refresh_token"
    t.datetime "oauth_expires_at"
    t.jsonb "oauth_metadata", default: {}
    t.string "platform_user_id"
    t.string "platform_username"
    t.string "encrypted_access_token"
    t.string "encrypted_refresh_token"
    t.bigint "client_id"
    t.datetime "metrics_synced_at", precision: nil
    t.index ["client_id"], name: "index_social_accounts_on_client_id"
    t.index ["user_id"], name: "index_social_accounts_on_user_id"
  end

  create_table "social_accounts_campaigns", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "social_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "social_account_id"], name: "idx_on_campaign_id_social_account_id_c51727054e", unique: true
    t.index ["campaign_id"], name: "index_social_accounts_campaigns_on_campaign_id"
    t.index ["social_account_id"], name: "index_social_accounts_campaigns_on_social_account_id"
  end

  create_table "strategy_histories", force: :cascade do |t|
    t.bigint "user_id"
    t.string "focus_area", default: "comprehensive"
    t.jsonb "metrics"
    t.jsonb "strategy"
    t.jsonb "insights"
    t.text "recommendations"
    t.jsonb "kpis_tracked"
    t.integer "overall_score", default: 0
    t.string "generated_by", default: "manual"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_strategy_histories_on_user_id"
  end

  create_table "subscription_plans", force: :cascade do |t|
    t.string "name"
    t.integer "price_cents"
    t.integer "credits"
    t.text "description"
    t.text "features"
    t.boolean "is_popular"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "user_subscriptions", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "subscription_plan_id"
    t.string "status", default: "pending"
    t.datetime "started_at"
    t.datetime "expires_at"
    t.integer "credits_used", default: 0
    t.string "stripe_subscription_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subscription_plan_id"], name: "index_user_subscriptions_on_subscription_plan_id"
    t.index ["user_id"], name: "index_user_subscriptions_on_user_id"
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
    t.string "agency_role"
    t.string "phone"
    t.string "business_name"
    t.text "ai_instructions"
    t.text "brand_voice_summary"
    t.text "brand_voice_examples"
    t.text "brand_voice_answers"
    t.text "brand_voice_document"
    t.datetime "brand_voice_generated_at"
    t.datetime "onboarding_completed_at"
    t.text "onboarding_steps", default: "{}"
    t.boolean "assistant_enabled", default: true
    t.text "brand_voice"
    t.boolean "onboarding_complete", default: false
    t.string "quality_tier", default: "standard"
    t.boolean "approved", default: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "videos", force: :cascade do |t|
    t.bigint "user_id"
    t.string "title"
    t.text "description"
    t.string "status"
    t.string "video_type"
    t.integer "duration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "error_message"
    t.string "video_url"
    t.string "prediction_url"
    t.index ["user_id"], name: "index_videos_on_user_id"
  end

  create_table "viral_metrics", force: :cascade do |t|
    t.bigint "scheduled_post_id", null: false
    t.bigint "campaign_id"
    t.bigint "client_id"
    t.decimal "engagement_rate", precision: 5, scale: 2
    t.decimal "share_velocity", precision: 10, scale: 4
    t.jsonb "top_hashtags", default: []
    t.string "trend_category"
    t.boolean "is_viral", default: false
    t.integer "viral_rank"
    t.datetime "detected_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "detected_at"], name: "index_viral_metrics_on_campaign_id_and_detected_at"
    t.index ["campaign_id"], name: "index_viral_metrics_on_campaign_id"
    t.index ["client_id", "detected_at"], name: "index_viral_metrics_on_client_id_and_detected_at"
    t.index ["client_id"], name: "index_viral_metrics_on_client_id"
    t.index ["detected_at"], name: "index_viral_metrics_on_detected_at"
    t.index ["is_viral"], name: "index_viral_metrics_on_is_viral"
    t.index ["scheduled_post_id"], name: "index_viral_metrics_on_scheduled_post_id"
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
    t.boolean "enabled"
    t.index ["user_id"], name: "index_voice_settings_on_user_id"
    t.index ["voice_id"], name: "index_voice_settings_on_voice_id"
  end

  create_table "waitlist_emails", force: :cascade do |t|
    t.string "email", null: false
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_waitlist_emails_on_email", unique: true
  end

  create_table "waitlists", force: :cascade do |t|
    t.string "email"
    t.boolean "status", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_waitlists_on_email", unique: true
  end

  create_table "workflow_steps", force: :cascade do |t|
    t.integer "workflow_id"
    t.string "step_type"
    t.string "status"
    t.integer "order"
    t.text "output"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "workflows", force: :cascade do |t|
    t.integer "user_id"
    t.string "workflow_type"
    t.string "status"
    t.text "params"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
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
  add_foreign_key "ai_generated_contents", "users"
  add_foreign_key "ai_task_results", "users"
  add_foreign_key "assistant_conversations", "users"
  add_foreign_key "auto_response_triggers", "users"
  add_foreign_key "auto_responses", "auto_response_triggers"
  add_foreign_key "auto_responses", "contents"
  add_foreign_key "auto_responses", "response_templates"
  add_foreign_key "auto_responses", "users"
  add_foreign_key "automation_rule_executions", "automation_rules"
  add_foreign_key "campaign_tasks", "campaigns"
  add_foreign_key "campaign_usages", "campaigns"
  add_foreign_key "campaigns", "clients"
  add_foreign_key "clients", "users"
  add_foreign_key "clients", "users", column: "agency_user_id"
  add_foreign_key "content_suggestions", "draft_contents"
  add_foreign_key "content_template_variables", "content_templates"
  add_foreign_key "post_analytics", "scheduled_posts"
  add_foreign_key "postforme_analytics", "scheduled_posts"
  add_foreign_key "publish_queues", "users"
  add_foreign_key "response_templates", "users"
  add_foreign_key "scheduled_ai_tasks", "users"
  add_foreign_key "scheduled_posts", "users", name: "scheduled_posts_user_id_fkey"
  add_foreign_key "sessions", "users"
  add_foreign_key "social_accounts", "clients"
  add_foreign_key "social_accounts_campaigns", "campaigns"
  add_foreign_key "social_accounts_campaigns", "social_accounts"
  add_foreign_key "task_executions", "scheduled_ai_tasks"
  add_foreign_key "task_executions", "users"
  add_foreign_key "trigger_executions", "auto_response_triggers"
  add_foreign_key "trigger_executions", "users"
  add_foreign_key "viral_metrics", "campaigns"
  add_foreign_key "viral_metrics", "clients"
  add_foreign_key "viral_metrics", "scheduled_posts"
end
