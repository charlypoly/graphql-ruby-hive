#!/bin/bash

log_with_prefix() {
    local prefix="$1"
    while IFS= read -r line; do
        echo "[$prefix] $line"
    done
}

start_puma_server() {
  local hive_enabled=$1
  local port=$2
  local prefix=$3

  echo "Starting Puma server with Hive ${hive_enabled}..."
  HIVE_ENABLED=$hive_enabled \
  PORT=$port \
  LOG_LEVEL=$LOG_LEVEL \
  bundle exec puma -C puma.rb | log_with_prefix "$prefix" &
}

# Start Node.js server
echo "Starting usage-api server..."
LOG_LEVEL=$LOG_LEVEL node usage-api.js | log_with_prefix "usage-api" &
# Start first Puma server
cd graphql-api || {
  echo "Could not find graphql-api" && exit 1
}
start_puma_server true 9291 "hive-enabled"
start_puma_server false 9292 "hive-disabled"

# Function to handle shutdown
shutdown_servers() {
    echo "Received shutdown signal. Shutting down servers..."
    kill $(lsof -t -i:9291)
    kill $(lsof -t -i:9292)
    kill $(lsof -t -i:8888)
    wait
    echo "Servers shut down gracefully."
    exit 0
}

# Listen for kill signals
trap shutdown_servers SIGINT SIGTERM

wait
