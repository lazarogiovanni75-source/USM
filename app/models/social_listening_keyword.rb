# frozen_string_literal: true

class SocialListeningKeyword < ApplicationRecord
  belongs_to :user
  validates :keyword, presence: true, uniqueness: { scope: :user_id }
end