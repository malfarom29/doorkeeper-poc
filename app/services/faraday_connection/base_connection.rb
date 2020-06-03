# frozen_string_literal: true

module FaradayConnection
  class BaseConnection
    class_attribute :url

    def initialize
      @api =
        Faraday.new(url: url) do |f|
          f.request :multipart
          f.request :url_encoded
          f.adapter :net_http
        end
    end

    def request(method, options = {})
      response = @api.public_send(method, options.fetch(:path, '')) do |req|
        req.params.merge!(options[:query]) if options[:query]
        req.body = options[:body].to_json if options[:body]
      end
      response
    end
  end
end
