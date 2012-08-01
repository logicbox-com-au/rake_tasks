# require 'yaml'
# conf = YAML.load_file("path/to/database.yml")

# to get all tasks, do a 'rake -T'

namespace :lb do
  
  namespace :db do

task :kill_postgres_connections do
  dbc = Rails.application.config.database_configuration[Rails.env]
  db_name = "#{dbc['database']}"
  puts "#{db_name}"
  sh = <<EOF
ps xa \
  | grep postgres: \
  | grep #{db_name} \
  | grep -v grep \
  | awk '{print $1}' \
  | xargs kill
EOF
  puts `#{sh}`
end


    desc "LogicBox - Create the database using settings"
    task :reset => [:drop, :create] do
      system "rake lb:db:pull"
      # system "rake db:migrate"
    end

    task :local_reset => [:drop, :create, :restore] do
    end
    
    desc "LogicBox - Create the database using settings"
    task :create do
      # In production, we'll need to do this as an example
      # sudo -u postgres  createdb -Othetransferstation -Eutf8 thetransferstation_production
      dbc = Rails.application.config.database_configuration[Rails.env]
      puts "Creating #{dbc['database']}..."
      system "createdb -T template0 -O #{dbc['username']} #{dbc['database']}"
      puts("Database #{dbc['database']} created")
    end

    desc "LogicBox - Drop the database using settings"
    task :drop => :kill_postgres_connections do
      dbc = Rails.application.config.database_configuration[Rails.env]
      puts "Dropping #{dbc['database']}..."
      system "dropdb -U #{dbc['username']} -i #{dbc['database']}"
      puts("Database #{dbc['database']} dropped")
    end

    desc "LogicBox - Dump database to db/dumps"
    task :backup do
      dbc = Rails.application.config.database_configuration[Rails.env]
      out = "db/dumps/#{dbc['database']}.sql"
      puts("Backing up #{Rails.env} database on #{dbc['host']}")
      system "pg_dump -U #{dbc['username']} -c #{dbc['database']} -f #{out}"
      puts("Database #{dbc['database']} backed up to #{out}")
    end
    
    desc "LogicBox - Restore database from db/dumps"
    task :restore do
      dbc = Rails.application.config.database_configuration[Rails.env]
      dbin = "db/dumps/#{dbc['database']}.sql"
      #  system "mysql -u #{dbc['username']} -h #{dbc['host']} -p#{dbc['password']} #{dbc['database']} < #{dbin}"
      system "psql -U #{dbc['username']} -d #{dbc['database']} -f #{dbin}"
      puts("Database #{dbc['database']} restored from #{dbin}")
    end
    
    desc "LogicBox - Archive database to /archives"
    task :archive do
      system "rake lb:db:backup"
      dbc = Rails.application.config.database_configuration[Rails.env]
      out = "archives/#{dbc['database']}_" + DateTime.now.strftime("%A_Hour%l").gsub(" ", "_").downcase + ".sql"
      system "pg_dump -U #{dbc['username']} #{dbc['database']} -f #{out}"
      #puts("Backing up #{Rails.env} database on #{dbc['host']} to #{out} for ROOT #{Rails.root}")
      #system "mysqldump -u #{dbc['username']} -h #{dbc['host']} -p#{dbc['password']} #{dbc['database']} > #{out}"
      #puts("Database #{dbc['database']} backed up to #{out}")
      system "cp #{out} archives/latest.sql"
    end
    
    desc "Replace remote db with local version"
    task :push do
      localdbc = Rails.application.config.database_configuration['development']
      remotedbc = Rails.application.config.database_configuration['production']
      out = "db/dumps/#{localdbc['database']}.sql"
      puts("Database #{localdbc['database']} performing local backup")
      system "rake lb:db:backup"
      puts("Database #{remotedbc['database']} performing backup on server (just to be safe)")
      system "cap sake:invoke task=lb:db:backup"
      puts("Copying local Database #{localdbc['database']} backup to server(and renaming to production)")
      system "scp #{out} railsuser@orion:/home/railsuser/#{Rails.application.class.parent_name.downcase}/current/db/dumps/#{remotedbc['database']}.sql"
      puts("Database #{remotedbc['database']} being restored/overwritten on server")
      system "cap sake:invoke task=lb:db:restore"
      puts("Rsync of images - pushing to server")
      system "rsync -avz -e ssh public/system railsuser@tts:~/#{Rails.application.class.parent_name.downcase}/shared"  
    end
    
    desc "Replace local db with remote version"
    task :pull do
      localdbc = Rails.application.config.database_configuration['development']
      remotedbc = Rails.application.config.database_configuration['production']
      out = "db/dumps/#{localdbc['database']}.sql"
      puts("Database #{remotedbc['database']} performing backup on server")
      system "cap sake:invoke task=lb:db:backup"
      puts("Database #{localdbc['database']} performing local backup (just to be safe)")
      system "rake lb:db:backup"
      puts("Copying remote Database #{remotedbc['database']} backup to local (and rename to dev)")
      system "scp railsuser@orion:/home/railsuser/#{Rails.application.class.parent_name.downcase}/current/db/dumps/#{remotedbc['database']}.sql #{out}"
      puts("Database #{localdbc['database']} being restored/overwritten locally")
      system "rake lb:db:restore"
      puts("Rsync of images - pulling from server")
      system "rsync -avz -e ssh railsuser@orion:~/#{Rails.application.class.parent_name.downcase}/shared/system public"
    end

    namespace :test do

      desc "LogicBox - Create the database using settings"
      task :reset do
        Rails.env = 'test'
        dbc = Rails.application.config.database_configuration['test']
        puts "Dropping #{dbc['database']}..."
        system "dropdb -U #{dbc['username']} -i #{dbc['database']}"
        puts "Creating #{dbc['database']}..."
        system "createdb -T template0 -O #{dbc['username']} #{dbc['database']}"
        system "rake db:schema:load RAILS_ENV=test"
      end

    end

    namespace :staging do
      
      desc "LogicBox - Reset staging from production"
      task :reset_from_production do
        system "sudo service apache2 stop"
        dbc = Rails.application.config.database_configuration['staging']
        puts "Dropping #{dbc['database']}..."
        system "sudo -u postgres dropdb -U postgres -i #{dbc['database']}"
        puts("Database #{dbc['database']} dropped")
        system "sudo -u postgres  createdb -Othetransferstationstaging -Eutf8 thetransferstation_staging"

        localdbc = Rails.application.config.database_configuration['staging']
        remotedbc = Rails.application.config.database_configuration['production']
        out = "db/dumps/#{localdbc['database']}.sql"
        puts("Database #{remotedbc['database']} performing backup on server")
        system "cap production sake:invoke task=lb:db:backup"
        puts("Copying remote Database #{remotedbc['database']} backup to local (and rename to dev)")
        system "scp railsuser@49.156.19.63:/home/railsuser/thetransferstation/current/db/dumps/#{remotedbc['database']}.sql #{out}"
        puts("Database #{localdbc['database']} being restored/overwritten locally")
        dbin = "db/dumps/#{localdbc['database']}.sql"
        system "psql -U #{localdbc['username']} -d #{localdbc['database']} -f #{dbin}"
        puts("Database #{localdbc['database']} restored from #{dbin}")
        puts("Rsync of images - pulling from server")
        system "rsync -avz -e ssh railsuser@49.156.19.63:~/thetransferstation/shared/system public"
        system "sudo service apache2 start"
      end
      
    end

  end

end


  
  
