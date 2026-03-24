class SocialAccountsCampaign < ApplicationRecord
  belongs_to :campaign
  belongs_to :social_account
end
