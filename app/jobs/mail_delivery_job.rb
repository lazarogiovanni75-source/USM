class MailDeliveryJob < ApplicationJob
  queue_as :mailers

  def perform(mailer, mail_method, delivery_method, args:, kwargs: nil, params: nil)
    kwargs ||= {}
    mail = mailer.constantize.with(params).public_send(mail_method, *args, **kwargs)
    
    case delivery_method.to_s
    when 'deliver_now'
      mail.deliver_now
    when 'deliver_later'
      mail.deliver_later
    else
      mail.send(delivery_method.to_sym)
    end
  end
end
