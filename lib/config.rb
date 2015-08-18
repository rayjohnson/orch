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

    def chronos_url
      if @options.has_key?("chronos_url")
        # If passed in on command line override what is in config file
        url = @options["chronos_url"]
        return url
      end

      if @APP_CONFIG.nil? || @APP_CONFIG["chronos_url"].nil?
        puts "chronos_url not specified, use --chronos_url or set in ~/.orch/config.yml"
        exit 1
      end

      return @APP_CONFIG["chronos_url"]
    end

    def marathon_url
      if @options.has_key?("marathon_url")
        # If passed in on command line override what is in config file
        url = @options["marathon_url"]
        return url
      end

      if @APP_CONFIG.nil? || @APP_CONFIG["marathon_url"].nil?
        puts "marathon_url not specified, use --marathon_url or set in ~/.orch/config.yml"
        exit 1
      end

      return @APP_CONFIG["marathon_url"]
    end

    def setup_config(marathon_url, chronos_url)

      if @APP_CONFIG.nil?
        @APP_CONFIG = {}
      end
      @APP_CONFIG['marathon_url'] = marathon_url
      @APP_CONFIG['chronos_url'] = chronos_url

      if ! File.directory?("#{Dir.home}/.orch")
        Dir.mkdir("#{Dir.home}/.orch")
      end
      File.open(@config_path, 'w') {|f| f.write @APP_CONFIG.to_yaml}
    end
  end
end
