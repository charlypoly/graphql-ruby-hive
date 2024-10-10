workers 2
threads 2, 2

port ENV.fetch("PORT", 9291)

preload_app!

on_worker_boot do
  GraphQL::Hive.instance.on_start
end

on_worker_shutdown do
  GraphQL::Hive.instance.on_exit
end
