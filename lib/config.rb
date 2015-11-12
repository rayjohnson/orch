# config

require 'json'
require 'yaml'

module Orch
  class Config
    def initialize(options)
      @options = options

      @config_path = "#{Dir.home}/.orch/config.yml"
      if File.file?(@config_path)
        @APP_CONFIG = YAML.load_file(@config_path)
      else
        @APP_CONFIG = nil
      end
    end

    def chronos_url(spec, app)
      if @options.has_key?("chronos_url")
        url = @options["chronos_url"]
        return url
      end

      if !app.chronos_url.nil?
        return app.chronos_url
      end

      if !spec.config.nil?
        if !spec.config.chronos_url.nil?
          return spec.config.chronos_url
        end
      end

      if !@APP_CONFIG.nil?
        if !@APP_CONFIG["chronos_url"].nil?
          return @APP_CONFIG["chronos_url"]
        end
      end

      return nil
    end

    def marathon_url(spec, app)
      if @options.has_key?("marathon_url")
        url = @options["marathon_url"]
        return url
      end

      if !app.marathon_url.nil?
        return app.marathon_url
      end

      if !spec.config.nil?
        if !spec.config.marathon_url.nil?
          return spec.config.marathon_url
        end
      end

      if !@APP_CONFIG.nil?
        if !@APP_CONFIG["marathon_url"].nil?
          return @APP_CONFIG["marathon_url"]
        end
      end

      return nil
    end

    def bamboo_url(spec, app)
      if @options.has_key?("bamboo_url")
        url = @options["bamboo_url"]
        return url
      end

      if !app.bamboo_url.nil?
        return app.bamboo_url
      end

      if !spec.config.nil?
        if !spec.config.bamboo_url.nil?
          return spec.config.bamboo_url
        end
      end

      if !@APP_CONFIG.nil?
        if !@APP_CONFIG["bamboo_url"].nil?
          return @APP_CONFIG["bamboo_url"]
        end
      end

      return nil
    end

    def setup_config(settings)

      if @APP_CONFIG.nil?
        @APP_CONFIG = {}
      end

      settings.each do |key, value|
        if settings[key] != ""
          @APP_CONFIG[key] = value
        end
      end

      if ! File.directory?("#{Dir.home}/.orch")
        Dir.mkdir("#{Dir.home}/.orch")
      end
      File.open(@config_path, 'w') {|f| f.write @APP_CONFIG.to_yaml}
    end
  end
end
