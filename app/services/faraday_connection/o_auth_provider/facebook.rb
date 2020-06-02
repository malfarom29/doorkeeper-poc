# frozen_string_literal: true

module FaradayConnection
  module OAuthProvider
    class Facebook < FaradayConnection::BaseConnection
      self.url = ENV['FACEBOOK_URL']

      def request_id(token)
        response = request(:get, query: { access_token: token })
        JSON.parse(response.body)['id']
      end
    end
  end
end
