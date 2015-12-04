class Orch::Config
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
    key_search("chronos_url", spec, app)
  end

  def marathon_url(spec, app)
    key_search("marathon_url", spec, app)
  end

  def bamboo_url(spec, app)
    key_search("bamboo_url", spec, app)
  end

  def key_search(key, spec, app)
    # First look if key was passed in as option
    if @options.has_key?(key)
      url = @options[key]
      return url
    end

    # Second look in the application level spec
    if !app[key].nil?
      return app[key]
    end

    # Third look in the config portion of the spec
    if !spec.config.nil?
      if !spec.config[key].nil?
        return spec.config[key]
      end
    end

    # Forth look in the config file
    if !@APP_CONFIG.nil?
      if !@APP_CONFIG[key].nil?
        return @APP_CONFIG[key]
      end
    end
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
