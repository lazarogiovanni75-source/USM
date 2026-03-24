#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick webhook test script
# Run with: rails runner test_webhook_now.rb

require '/home/runner/app/config/environment'

puts "=" * 60
puts "Webhook Flow Quick Test"
puts "=" * 60

puts "\n[1] Checking configuration..."
webhook_url = ENV.fetch('MAKE_WEBHOOK_URL', 'NOT SET')
puts "   Webhook URL: #{webhook_url}"

puts "\n[2] Finding test data..."
user = User.first
content = Content.first
social_account = SocialAccount.first

if user.nil? || content.nil? || social_account.nil?
  puts "   ERROR: Missing test data. Run db:seed first."
  exit 1
end

puts "   User: ##{user.id} - #{user.email}"
puts "   Content: ##{content.id} - #{content.title}"
puts "   SocialAccount: ##{social_account.id} - #{social_account.platform}"

puts "\n[3] Creating test ScheduledPost..."
post = ScheduledPost.create!(
  content: content,
  social_account: social_account,
  user: user,
  scheduled_at: 1.hour.from_now,
  status: :scheduled
)

puts "   Created: ##{post.id}"
puts "   webhook_status: #{post.webhook_status}"

puts "\n[4] Checking webhook job..."
sleep 1 # Give job time to be created
job = GoodJob::Job.where(job_class: 'PostWebhookJob').last
if job
  puts "   Job found: #{job.id}"
  puts "   State: #{job.state}"
else
  puts "   No PostWebhookJob found in queue"
end

puts "\n[5] Running webhook job..."
begin
  post_job = PostWebhookJob.new
  post_job.perform(post.id, 'created')
  puts "   Job executed successfully!"
rescue StandardError => e
  puts "   Job failed: #{e.message}"
end

post.reload
puts "\n[6] Final status:"
puts "   webhook_status: #{post.webhook_status}"
puts "   webhook_attempts: #{post.webhook_attempts}"
puts "   webhook_error: #{post.webhook_error || 'None'}"

puts "\n" + "=" * 60
if post.webhook_status == 'success'
  puts "✅ Webhook sent successfully!"
else
  puts "⚠️  Webhook status: #{post.webhook_status}"
  puts "   Make sure your Make scenario is running and listening."
end
puts "=" * 60
