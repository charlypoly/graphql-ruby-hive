# GraphQL Hive: `graphql-ruby` integration 
[![CI Suite](https://github.com/charlypoly/graphql-ruby-hive/actions/workflows/ci.yml/badge.svg)](https://github.com/charlypoly/graphql-ruby-hive/actions)
[![Gem Version](https://badge.fury.io/rb/graphql-hive.svg)](https://rubygems.org/gems/graphql-hive)

<p align="center">
  <img src="cover.png" width="500" alt="GraphQL Hive" />
</p>



[GraphQL Hive](https://graphql-hive.com/) provides all the tools to get visibility of your GraphQL architecture at all stages, from standalone APIs to composed schemas (Federation, Stitching):
- **Schema Registry** with custom breaking changes detection
- **Monitoring** of RPM, latency, error rate, and more
- **Integrations** with your favorite tools (Slack, Github Actions, and more)


<br/>

----

<br/>


# Getting started


## 0. Get your Hive token

If you are using Hive as a service, please refer to our documentation: https://docs.graphql-hive.com/features/tokens.

## 1. Install the `graphql-hive` gem

```
gem install graphql-hive
```

<br/>

## 2. Configure `GraphQL::Hive` in your Schema

Add `GraphQL::Hive` **at the end** of your schema definition:

```ruby
class Schema < GraphQL::Schema
  query QueryType

  use(
      GraphQL::Hive,
      {
        token: '<YOUR_TOKEN>',
        reporting: {
          author: ENV['GITHUB_USER'],
          commit: ENV['GITHUB_COMMIT']
        },
      }
  )
end

```

The `reporting` configuration is required to push your GraphQL Schema to the Hive registry.
Doing so will help better detect breaking changes and more upcoming features.
If you only want to use the operations monitoring, replace the `reporting` option with the following `report_schema: false`.

<br/>

## 3. (Optional) Configure Lifecycle Hooks

Calling these hooks are situational - it's likely that you may not need to call
them at all!

### `on_start`

Call this hook if you are running `GraphQL::Hive` in a process that `fork`s
itself.

example: `puma` web server running in (["clustered
mode"](https://github.com/puma/puma/tree/6d8b728b42a61bcf3c1e4c698c9165a45e6071e8#clustered-mode))

```ruby
# config/puma.rb
preload_app!

on_worker_boot do
  GraphQL::Hive.instance.on_start
end
```

### `on_exit`

If your GraphQL API process is shut down non-gracefully but has a shutdown hook
to call into, call `on_worker_exit`.

`puma` example:

```ruby
# config/puma.rb

on_worker_shutdown do
  GraphQL::Hive.instance.on_exit
end
```

<br />

**You are all set! 🚀**

When deploying or starting up your GraphQL API, `graphql-hive` will immediately:
- publish the schema to the Hive registry
- forward the operations metrics to Hive


<br/>

## 4. See how your GraphQL API is operating

You should now see operations information (RPM, error rate, queries performed) on your [GraphQL Hive dashboard](https://app.graphql-hive.com/):

<p align="center">
  <img src="operations-dashboard.png" width="500" alt="GraphQL Hive" />
</p>


<br/>


## 5. Going further: use the Hive Github app

Stay on top of your GraphQL Schema changes by installing the Hive Github Application and enabling Slack notifications about breaking changes:

https://docs.graphql-hive.com/features/integrations#github

<br/>

----

<br/>


# Configuration

You will find below the complete list of options of `GraphQL::Hive`:

```ruby
class MySchema < GraphQL::Schema
  use(
    GraphQL::Hive,
    {
      token: 'YOUR-TOKEN',
      collect_usage: true, # report usage to Hive (optional)
      report_schema: true,  # publish schema to Hive (optional)
      enabled: true, # enable/disable Hive Client (optional)
      debug: false, # verbose logs
      logger: MyLogger.new,  # optional
      endpoint: 'app.graphql-hive.com',  # optional
      port: 80,  # optional
      buffer_size: 50, # forward the operations data to Hive every 50 requests (optional)
      collect_usage_sampling: 1.0, # report % of operations (optional)
      reporting: {  # mandatory if `report_schema: true`
        author: 'Author of the latest change', # mandatory member of `reporting`
        commit: 'git sha or any identifier',  # mandatory member of `reporting`
        service_name: '', # optional
        service_url: '', # optional
      },
      # you can pass an optional proc that will help identify the client (ex: Apollo web app) that performed the query
      client_info: Proc.new { |context| { name: context.client_name, version: context.client_version } }
      # NOTE: the following field overrides collect_usage_sampling
      # if you want all operations to be sampled at least once, you can pass an optional proc to conditionally assign sampling rates, based on the sampling context of the operation
      collect_usage_sampler: Proc.new { |sampling_context| sampling_context.operation_name.includes?('someQuery') 1 : 0.2 }
      # if you use a sampler, you can pass an optional proc to specify how operations should be keyed, based on the sampling context of the operation
      sample_key_generator: Proc.new { |sampling_context| sampling_context.operation_name }
    }
  )

  # ...

end
```

<br/>

**A note on `buffer_size` and performances**

The `graphql-hive` usage reporter, responsible for sending the operations data to Hive, is running in a separate `Thread` to avoid any significant impact on your GraphQL API performances.

The performance overhead (with the default `buffer_size` option) is around 1% and [is constantly evaluated for new PR](https://github.com/charlypoly/graphql-ruby-hive/actions/workflows/benchmark.yml).

If your GraphQL API has a high RPM, we encourage you to increase the `buffer_size` value.

However, please note that a higher `buffer_size` value will introduce some peak of increase in memory consumption.
