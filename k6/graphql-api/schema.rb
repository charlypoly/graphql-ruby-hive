require "graphql"
require "graphql-hive"

module Types
  class PostType < GraphQL::Schema::Object
    description "A blog post"
    field :id, ID, null: false
    field :title, String, null: false
    # fields should be queried in camel-case (this will be `truncatedPreview`)
    field :truncated_preview, String, null: false
  end
end

class QueryType < GraphQL::Schema::Object
  description "The query root of this schema"

  # First describe the field signature:
  field :post, Types::PostType, "Find a post by ID" do
    argument :id, [ID]
  end

  # Then provide an implementation:
  def post(id:)
    {id: 1, title: "GraphQL Hive with `graphql-ruby`",
     truncated_preview: "Monitor operations, inspect your queries and publish your GraphQL schema with GraphQL Hive"}
  end
end

class Schema < GraphQL::Schema
  query QueryType

  use(
    GraphQL::Hive,
    enabled: ENV["HIVE_ENABLED"] === "true",
    endpoint: "localhost",
    debug: false,
    buffer_size: 10,
    port: 8888,
    token: "stress-token",
    report_schema: false
  )
end
