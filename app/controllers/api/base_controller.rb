# app/controllers/api/base_controller.rb
module Api
  class BaseController < ActionController::API
    include Authenticable
  end
end
