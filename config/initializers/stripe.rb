Stripe.api_key = begin
  if Rails.env.production?
    Rails.application.credentials.dig(:stripe, :production, :secret_key)
  else
    Rails.application.credentials.dig(:stripe, :development, :secret_key)
  end
rescue
  nil
end
