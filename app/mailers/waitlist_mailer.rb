class WaitlistMailer < ApplicationMailer
  def confirmation_email(entry)
    @entry = entry
    mail(
      to: @entry.email,
      subject: "You're on the list — Ultimate Social Media"
    )
  end
end
