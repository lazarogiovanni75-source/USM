# frozen_string_literal: true

class SocialListeningHashtag < ApplicationRecord
  belongs_to :user
  validates :hashtag, presence: true, uniqueness: { scope: :user_id }
end