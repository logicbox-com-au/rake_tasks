require 'rake_tasks'
require 'rails'
module RakeTasks
  class Railtie < Rails::Railtie
    railtie_name :rake_tasks

    rake_tasks do
      load "tasks/logicbox.rake"
    end
  end
end
