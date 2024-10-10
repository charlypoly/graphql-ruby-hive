require "sinatra"
require "sinatra/json"
require "rack/contrib"
require "logger"

require_relative "schema"

class DemoApp < Sinatra::Base
  use Rack::JSONBodyParser

  configure do
    set :logger, Logger.new(STDOUT)
    log_level = ENV.fetch("LOG_LEVEL", "INFO").upcase
    logger.level = begin
      Logger.const_get(log_level)
    rescue
      Logger::INFO
    end
  end

  before do
    env["rack.logger"] = settings.logger
  end

  get "/" do
    json status: "ok"
  end

  post "/graphql" do
    logger.debug("Received query: #{params[:operationName]}")

    result = Schema.execute(
      params["query"],
      variables: params[:variables],
      operation_name: params[:operationName],
      context: {
        client_name: "GraphQL Client",
        client_version: "1.0"
      }
    )
    json result
  end
end
