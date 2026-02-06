module Api
  module V1
    class PostformeWebhooksController < Api::BaseController
      def receive
        head :ok
      end
    end
  end
end
