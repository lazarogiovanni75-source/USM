class OttoMessage < ApplicationRecord
  def self.table_exists?
    connection.table_exists?(:otto_messages)
  rescue
    false
  end

  belongs_to :user

  validates :role, inclusion: { in: %w[user assistant] }
  validates :content, presence: true

  scope :recent, -> { order(created_at: :asc).last(20) }
end
