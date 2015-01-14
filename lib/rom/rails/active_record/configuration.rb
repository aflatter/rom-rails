require 'addressable/uri'

module ROM
  module Rails
    module ActiveRecord
      # A helper class to derive a repository configuration from ActiveRecord.
      #
      # @private
      class Configuration
        BASE_OPTIONS = [
          :root,
          :adapter,
          :database,
          :password,
          :username,
          :hostname,
          :root
        ].freeze

        # Returns repository configuration for the current environment.
        #
        # @note This relies on ActiveRecord being initialized already.
        # @param [Rails::Application]
        #
        # @api private
        def self.call(app)
          configuration = ::ActiveRecord::Base.configurations[::Rails.env]
                          .symbolize_keys
                          .update(root: app.config.root)

          build(configuration)
        end

        # Builds a configuration hash from a flat database config hash.
        #
        # This is used to support typical database.yml-complaint configs. It
        # also uses adapter interface for things that are adapter-specific like
        # handling schema naming.
        #
        # @param [Hash,String]
        # @return [Hash]
        #
        # @api private
        def self.build(config)
          adapter = config.fetch(:adapter)
          uri_options = config.except(:adapter).merge(scheme: adapter)
          other_options = config.except(*BASE_OPTIONS)

          builder_method = :"#{adapter}_uri"
          uri = if respond_to?(builder_method)
                  send(builder_method, uri_options)
                else
                  generic_uri(uri_options)
                end


          # JRuby connection strings require special care.
          uri = if RUBY_ENGINE == 'jruby' && adapter != 'postgresql'
                  "jdbc:#{uri}"
                 else
                   uri
                 end

          config_hash(uri, other_options)
        end

        def self.sqlite3_uri(config)
          path = Pathname.new(config.fetch(:root)).join(config.fetch(:database))

          build_uri(
            scheme: 'sqlite',
            host: '',
            path: path.to_s
          )
        end

        def self.postgresql_uri(config)
          config.update(scheme: 'postgres')

          unless config[:host]
            config.update(host: '')
            auth_params = config.extract!(:username, :password)
            config.update(query_values: auth_params) if auth_params.any?
          end

          generic_uri(config)
        end

        def self.mysql_uri(config)
          if config.key?(:username) && !config.key?(:password)
            config.update(password: '')
          end

          generic_uri(config)
        end

        def self.generic_uri(config)
          build_uri(
            scheme: config.fetch(:scheme),
            user: config[:username],
            password: config[:password],
            host: config[:host],
            port: config[:port],
            path: config[:database],
            query_values: config[:query_values]
          )
        end

        def self.build_uri(attrs)
          Addressable::URI.new(attrs).to_s
        end

        # @api private
        def self.config_hash(uri, options = {})
          if options.any?
            { uri: uri, options: options }
          else
            uri
          end
        end
      end
    end
  end
end
