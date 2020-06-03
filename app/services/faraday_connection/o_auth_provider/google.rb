# frozen_string_literal: true

module FaradayConnection
  module OAuthProvider
    class Google < FaradayConnection::BaseConnection
      include Provider
      self.url = ENV['GOOGLE_URL']
    end
  end
end
