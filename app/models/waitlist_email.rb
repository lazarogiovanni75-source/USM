class WaitlistEmail < ApplicationRecord
  self.table_name = 'waitlist_emails'

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
end
