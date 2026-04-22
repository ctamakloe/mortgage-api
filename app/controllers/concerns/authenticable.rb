module Authenticable
  extend ActiveSupport::Concern

  RATE_LIMIT = 100
  RATE_WINDOW = 1.minute

  included do
    before_action :authenticate!
    before_action :enforce_rate_limit!
    around_action :log_request
  end

  private

  def authenticate!
    header = request.headers["Authorization"]
    token = header&.match(/^Bearer (.+)$/)&.captures&.first

    @current_api_client = ApiClient.authenticate(token)

    return if @current_api_client

    head :unauthorized
    return # rubocop:disable Style/RedundantReturn
  end

  def current_api_client
    @current_api_client
  end

  def log_request
    start_time = Time.current

    yield
  rescue StandardError => e
    @response_status = 500
    raise e
  ensure
    ApiRequest.create!(
      api_client: current_api_client,
      method: request.method,
      path: request.fullpath,
      status: response&.status || @response_status || 500,
      metadata: {
        ip: request.remote_ip,
        user_agent: request.user_agent,
        duration_ms: ((Time.current - start_time) * 1000).round,
        authenticated: current_api_client.present?,
      },
    )
  end

  def enforce_rate_limit!
    return unless current_api_client

    window_start = RATE_WINDOW.ago

    request_count = ApiRequest.where(api_client: current_api_client)
                              .where("created_at >= ?", window_start)
                              .count

    return if request_count < RATE_LIMIT

    render json: { error: "Rate limit exceeded" }, status: :too_many_requests
  end
end
