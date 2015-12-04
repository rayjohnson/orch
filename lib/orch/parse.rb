class Orch::Parse

  CURRENT_SPEC_VERSION=1.0

  def initialize(path, options)
    if ! File.file?(path)
      exit_with_msg "file does not exist: #{path}"
    end

    begin
      yaml = ::YAML.load_file(path)
    rescue Psych::SyntaxError => e
      exit_with_msg "error parsing yaml file #{e}"
    end

    @options = options

    @spec = Hashie::Mash.new(yaml)
  end

  def parse(dry_run)
    @dry_run = dry_run
    check_option_syntax
    check_version
    spec = @spec

    # Check for vault vars
    env_var_values = parse_vault_vars(@spec)

    # Check for env values at spec level
    if ! spec.env.nil?
      env_var_values = env_var_values.merge(spec.env)
    end

    if spec.applications.nil?
      exit_with_msg "required section applications: must have at least one application defined"
    end

    results = []
    spec.applications.each do |app|
      # Check for valid kind paramter
      if app.kind.nil?
        exit_with_msg "required field 'kind:' was not found"
      end

      if !(app.kind == "Chronos" || app.kind == "Marathon")
        exit_with_msg "unsupported kind specified: #{app.kind} - must be: Chronos | Marathon"
      end

      # Generate any deploy variables that need to be merged in
      deploy_vars = parse_deploy_vars(app)
      app_var_values = env_var_values.merge(deploy_vars)

      # Check for env values at app level
      if ! app.env.nil?
        app_var_values = app_var_values.merge(app.env)
      end

      if (app.kind == "Chronos")
        chronos_spec = parse_chronos(app, app_var_values)

        result = {
          :name => chronos_spec["name"], 
          :type => app.kind, 
          :deploy => should_deploy?(app), 
          :env_vars => deploy_vars, 
          :json => chronos_spec,
          :url => $ORCH_CONFIG.chronos_url(spec, app)
        }

        results << result
      end

      if (app.kind == "Marathon")
        marathon_spec = parse_marathon(app, app_var_values)

        result = {
          :name => marathon_spec["id"], 
          :type => app.kind, 
          :deploy => should_deploy?(app), 
          :env_vars => deploy_vars, 
          :json => marathon_spec,
          :url => $ORCH_CONFIG.marathon_url(spec, app)
        }

        if app.bamboo_spec
          bamboo_spec = parse_bamboo(app, app_var_values)
          result[:bamboo_spec] = bamboo_spec
          result[:bamboo_url] = $ORCH_CONFIG.bamboo_url(spec, app)
        end

        results << result
      end

    end

    results
  end

  def parse_deploy_vars(app)
    result = {}
    if (! @spec.deploy_vars.nil?)
      @spec.deploy_vars.each do |key, value|
        if app[key].nil?
          exit_with_msg "deploy_var #{key} specified - but not included in app"
          # TODO: would be nice to put the app name...
        end
        if ! @spec.deploy_vars[key].include? app[key]
          exit_with_msg "#{key} value \"#{app[key]}\" not in #{@spec.deploy_vars[key].to_s}"
        end
        result[key] = app[key]
      end
    end

    result
  end

  def parse_vault_vars(spec)
    result = {}
    if ! spec.vault.nil?
      count = 1
      spec.vault.each do |vault_key|
        result["VAULT_KEY_#{count}"] = vault_key
        count += 1
      end
    end
    result
  end

  def parse_chronos(app, env_var_values)
    if app.chronos_spec.nil?
      exit_with_msg "App of kind: Chronos requires a 'chronos_spec:' field"
    end
    chronos_spec = app.chronos_spec

    # Override out high-level env vars with any chronos_spec level vars
    env_vars = env_var_values
    (chronos_spec.environmentVariables || []).each do |x|
      env_vars[x["name"]] = x["value"]
    end

    # Rewrite the environmentVariables from the hash
    chronos_spec.environmentVariables = []
    env_vars.each do |key, value|
      pair = {"name" => key, "value" => value}
      chronos_spec.environmentVariables << pair        
    end

    # Do subst processing
    spec_str = do_subst(chronos_spec, app)

    JSON.parse(spec_str)
  end

  def parse_marathon(app, env_var_values)
    if app.marathon_spec.nil?
      exit_with_msg "App of kind: Marathon requires a 'marathon_spec:' field"
    end
    marathon_spec = app.marathon_spec

    # Augment any spec environment variables with meta values - but don't overwite
    marathon_spec.env = {} unless marathon_spec.env
    env_var_values.each do |key, value|
      marathon_spec.env[key] = value.to_s unless marathon_spec.env[key] 
    end

    if marathon_spec.id
      marathon_spec.id = (marathon_spec.id[0] == '/') ? marathon_spec.id : ("/" + marathon_spec.id)
    else
      exit_with_msg "id: is a required field for a marathon spec"
    end

    spec_str = do_subst(marathon_spec, app)

    JSON.parse(spec_str)
  end

  def parse_bamboo(app, env_var_values)
    # Do any substs
    spec_str = do_subst(app.bamboo_spec, app)
    bamboo_spec = JSON.parse(spec_str)

    if bamboo_spec['acl'].nil?
      puts "required field 'acl:' missing from bamboo_spec"
    end

    bamboo_spec
  end

  def should_deploy?(app)
    result = true
    if @options[:deploy_kind] != 'all' && app.kind != @options[:deploy_kind]
      result = false
    end

    if @options[:deploy_var] != 'all'
      @options[:deploy_var].split(",").each do |x|
        pair = x.split("=")
        deployVar = pair[0]
        deployVal = pair[1]
        if app[deployVar].nil?
          exit_with_msg "environment var of '#{deployVar}' not found in app"
        end
        if app[deployVar] != deployVal
          result = false
        end
      end
    end

    result
  end

  def do_subst(spec, app)
    spec_str = spec.to_json.to_s

    # Subst any of the deploy_vars values
    if (! @spec.deploy_vars.nil?)
      @spec.deploy_vars.each do |key, value|
        spec_str = spec_str.gsub(/{{#{key}}}/, app[key])
      end
    end

    # Subst any values that were passed in via command line
    if ! @options[:subst].nil?
      @options[:subst].split(",").each do |x|
        pair = x.split("=")
        spec_str = spec_str.gsub(/{{#{pair[0]}}}/, pair[1])
      end
    end

    # Check if any substitution variables still exist
    tag_match = /{{\w+}}/.match(spec_str)
    if !tag_match.nil?
      exit_with_msg "unsubstituted varaibles still remain in spec: #{tag_match.to_s}"
    end

    spec_str
  end

  def check_version

    # Check for valid version paramter
    if @spec.version.nil?
      exit_with_msg "required field version was not found"
    end

    if @spec.version == "alpha1"
      # Getting rid of alpha1 syntax and just going to number syntax.  Will support this for a little bit...
      version = 1.0
    else

      number = Float( @spec.version ) rescue nil
      if number.nil? 
        exit_with_msg "invalid value \"#{@spec.version}\" for version field of spec"
      end
      version = number
    end

    if version > CURRENT_SPEC_VERSION
      STDERR.puts "warning: spec version greater than software supports - may get failure or unexpected behavior"
    end

    # If we get to point where we need to support older formats - determine that here.
  end

  def check_option_syntax
    if @dry_run
      return
    end

    if ! ['chronos', 'marathon', 'all'].include?(@options[:deploy_kind])
      exit_with_msg "value of --deploy-type was #{@options[:deploy_kind]}, must be chronos, marathon or all"
    end
  end
end
