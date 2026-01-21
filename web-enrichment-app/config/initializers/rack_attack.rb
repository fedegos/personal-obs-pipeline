Rack::Attack.throttle('limit logins per email', limit: 5, period: 20.seconds) do |req|
  if req.path == '/users/sign_in' && req.post?
    req.params['user']['email'].to_s.downcase.gsub(/\s+/, "")
  end
end
