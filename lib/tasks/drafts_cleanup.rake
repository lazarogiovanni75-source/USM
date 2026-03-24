# Rake task to auto-delete unused drafts after 30 days
# Run daily with: rake drafts:auto_delete

namespace :drafts do
  desc "Delete drafts older than 30 days that have not been used"
  task auto_delete: :environment do
    cutoff_date = 30.days.ago
    
    # Find old unused drafts
    old_drafts = DraftContent.where("created_at < ?", cutoff_date)
                           .where(status: 'draft')
                           .where("updated_at < ?", cutoff_date)
    
    count = old_drafts.count
    old_drafts.destroy_all
    
    puts "Deleted #{count} drafts older than 30 days"
  end
end
