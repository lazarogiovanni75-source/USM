# Seed content templates for starter pack
class CreateStarterPackTemplates < ApplicationJob
  queue_as :default
  
  def perform
    ContentTemplate.create_starter_pack_templates
    puts "Created #{ContentTemplate.count} starter pack templates"
  end
end