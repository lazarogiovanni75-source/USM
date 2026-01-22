class Content < ApplicationRecord
  belongs_to :campaign
  belongs_to :user

  serialize :media_urls, coder: JSON
end
