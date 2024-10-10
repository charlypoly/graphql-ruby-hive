require "sinatra"
require "sinatra/json"
require "rack/contrib"
require "logger"

require_relative "schema"

class DemoApp < Sinatra::Base
  use Rack::JSONBodyParser
  set :logger, Logger.new(STDOUT)

  get "/" do
    status 200
  end

  post "/graphql" do
    logger.info("Received query: #{params["query"]}")
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
