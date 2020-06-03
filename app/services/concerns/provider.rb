# frozen_string_literal: true

module Provider
  def request_id(token)
    response = request(:get, query: { access_token: token })
    JSON.parse(response.body)['id']
  end
end
