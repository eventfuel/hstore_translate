require 'minitest/autorun'
require 'hstore_translate'

require 'database_cleaner'
DatabaseCleaner.strategy = :transaction

I18n.available_locales = [:en, :fr]

class Post < ActiveRecord::Base
  translates :title
end

class PostDetailed < Post
  translates :comment
end

class HstoreTranslate::Test < Minitest::Test
  class << self
    def prepare_database
      create_database
      create_table
    end

    private

    def db_config
      @db_config ||= begin
        filepath = File.join('test', 'database.yml')
        YAML.load_file(filepath)['test']
      end
    end

    def establish_connection(config)
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection
    end

    def create_database
      system_config = db_config.merge('database' => 'postgres', 'schema_search_path' => 'public')
      connection = establish_connection(system_config)
      connection.create_database(db_config['database']) rescue nil
      enable_extension
    end

    def enable_extension
      connection = establish_connection(db_config)
      unless connection.select_value("SELECT proname FROM pg_proc WHERE proname = 'akeys'")
        if connection.send(:postgresql_version) < 90100
          pg_sharedir = `pg_config --sharedir`.strip
          hstore_script_path = File.join(pg_sharedir, 'contrib', 'hstore.sql')
          connection.execute(File.read(hstore_script_path))
        else
          connection.execute('CREATE EXTENSION IF NOT EXISTS hstore')
        end
      end
    end

    def create_table
      connection = establish_connection(db_config)
      connection.create_table(:posts, :force => true) do |t|
        t.column :title_translations, 'hstore'
        t.column :comment_translations, 'hstore'
      end
    end
  end

  prepare_database

  def setup
    I18n.available_locales = ['en', 'en-US', 'fr']
    I18n.config.enforce_available_locales = true
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end
end
