require "rake_tasks/version"

module RakeTasks
  require 'rake_tasks/railtie' if defined?(Rails)
end
