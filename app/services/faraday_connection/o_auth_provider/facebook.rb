# frozen_string_literal: true

module FaradayConnection
  module OAuthProvider
    class Facebook < FaradayConnection::BaseConnection
      include Provider
      self.url = ENV['FACEBOOK_URL']
    end
  end
end
