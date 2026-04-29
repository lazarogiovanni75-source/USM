# frozen_string_literal: true

class SocialListeningJob < ApplicationJob
  queue_as :default

  def perform(user_id = nil)
    if user_id
      user = User.find(user_id)
      keywords = user.social_listening_keywords.pluck(:keyword)
      hashtags = user.social_listening_hashtags.pluck(:hashtag)

      # Listen for keywords
      if keywords.any?
        mentions = SocialListeningService.listen_for_keywords(keywords)
        SocialListeningService.create_alerts(user, mentions, 'keyword')
      end

      # Listen for hashtags
      if hashtags.any?
        mentions = SocialListeningService.track_hashtags(hashtags)
        SocialListeningService.create_alerts(user, mentions, 'hashtag')
      end
    end
  end
end