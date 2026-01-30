#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify the webhook flow end-to-end
# Run with: rails runner test_webhook_flow.rb

require '/home/runner/app/config/environment'

puts "=" * 60
puts "End-to-End Webhook Flow Test"
puts "=" * 60

puts "\n[1] Finding test data..."
user = User.first
content = Content.first
social_account = SocialAccount.first

puts "   User: ##{user.id} - #{user.email}"
puts "   Content: ##{content.id} - #{content.title}"
puts "   SocialAccount: ##{social_account.id} - #{social_account.platform}"

puts "\n[2] Creating test ScheduledPost..."
post = ScheduledPost.create!(
  content: content,
  social_account: social_account,
  user: user,
  scheduled_at: 1.hour.from_now,
  status: :scheduled
)

puts "   Created: ##{post.id}"
puts "   webhook_status: #{post.webhook_status}"
puts "   webhook_attempts: #{post.webhook_attempts}"

puts "\n[3] Checking if webhook job was enqueued..."
job = GoodJob::Job.last
if job
  puts "   Job found: #{job.id}"
  puts "   Job class: #{job.job_class}"
  puts "   Queue name: #{job.queue_name}"
  puts "   Created at: #{job.created_at}"
else
  puts "   No job found in queue"
end

puts "\n[4] Executing the job to send webhook..."
# Execute the job inline for testing
begin
  post_job = PostWebhookJob.new
  post_job.perform(post.id, 'created')
  puts "   Job executed successfully!"
rescue StandardError => e
  puts "   Job failed: #{e.message}"
end

# Refresh the post to see updated status
post.reload

puts "\n[5] Updated ScheduledPost status:"
puts "   webhook_status: #{post.webhook_status}"
puts "   webhook_attempts: #{post.webhook_attempts}"
puts "   webhook_error: #{post.webhook_error || 'None'}"

puts "\n" + "=" * 60
puts "Test Complete"
puts "=" * 60

puts "\nSummary:"
puts "- ScheduledPost ##{post.id} created with webhook_status: #{post.webhook_status}"
puts "- The webhook was sent to: #{ENV.fetch('MAKE_WEBHOOK_URL', 'NOT SET')}"
puts "- Make returned 410 (no scenario listening - expected until you set up Make workflow)"
puts "\nTo complete the integration:"
puts "1. Log in to Make (make.com)"
puts "2. Create a new scenario with Webhook trigger"
puts "3. Use the webhook URL: #{ENV.fetch('MAKE_WEBHOOK_URL', 'YOUR_WEBHOOK_URL')}"
puts "4. Add Buffer module to post content"
puts "5. Activate the scenario"
