class WaitlistEmail < ApplicationRecord
  self.table_name = 'waitlists'

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
end
