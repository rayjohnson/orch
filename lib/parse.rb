require 'yaml'
require 'json'

CURRENT_SPEC_VERSION=1.0

module Orch
  class Parse

    def initialize(path, options)
      if ! File.file?(path)
        puts "file does not exist: #{path}"
        exit 1
      end

      begin
        yaml = ::YAML.load_file(path)
      rescue Psych::SyntaxError => e
        puts "error parsing yaml file #{e}"
        exit 1
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
        puts "required section applications: must have at least one application defined"
        exit 1
      end

      results = []
      spec.applications.each do |app|
        # Check for valid kind paramter
        if app.kind.nil?
          puts "required field 'kind:' was not found"
          exit 1
        end

        if !(app.kind == "Chronos" || app.kind == "Marathon")
          puts "unsupported kind specified: #{app.kind} - must be: Chronos | Marathon"
          exit 1
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

          result = {:name => chronos_spec["name"], :type => app.kind, :deploy => should_deploy?(app), :env_vars => deploy_vars, :json => chronos_spec}
          results << result
        end

        if (app.kind == "Marathon")
          marathon_spec = parse_marathon(app, app_var_values)

          result = {:name => marathon_spec["id"], :type => app.kind, :deploy => should_deploy?(app), :env_vars => deploy_vars, :json => marathon_spec}

          if app.bamboo_spec
            bamboo_spec = parse_bamboo(app, app_var_values)
            result[:bamboo_spec] = bamboo_spec
          end

          results << result
        end

      end

      return results
    end

    def parse_deploy_vars(app)
      result = {}
      if (! @spec.deploy_vars.nil?)
        @spec.deploy_vars.each do |key, value|
          if app[key].nil?
            puts "deploy_var #{key} specified - but not included in app"
            # TODO: would be nice to put the app name...
            exit 1
          end
          if ! @spec.deploy_vars[key].include? app[key]
            puts "#{key} value \"#{app[key]}\" not in #{@spec.deploy_vars[key].to_s}"
            exit 1
          end
          result[key] = app[key]
        end
      end

      return result
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
      return result
    end

    def parse_chronos(app, env_var_values)
      if app.chronos_spec.nil?
        puts "App of kind: Chronos requires a 'chronos_spec:' field"
        exit 1
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
      chronos_spec = JSON.parse(spec_str)

      return chronos_spec
    end

    def parse_marathon(app, env_var_values)
      if app.marathon_spec.nil?
        puts "App of kind: Marathon requires a 'marathon_spec:' field"
        exit 1
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
        puts "id: is a required field for a marathon spec"
        exit 1
      end

      spec_str = do_subst(marathon_spec, app)
      marathon_spec = JSON.parse(spec_str)

      return marathon_spec
    end

    def parse_bamboo(app, env_var_values)
      # Do any substs
      spec_str = do_subst(app.bamboo_spec, app)
      bamboo_spec = JSON.parse(spec_str)

      if bamboo_spec['acl'].nil?
        puts "required field 'acl:' missing from bamboo_spec"
      end

      return bamboo_spec
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
            puts "environment var of '#{deployVar}' not found in app"
            exit 1
          end
          if app[deployVar] != deployVal
            result = false
          end
        end
      end

      return result
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
        puts "unsubstituted varaibles still remain in spec: #{tag_match.to_s}"
        exit 1
      end

      return spec_str
    end

    def check_version

      # Check for valid version paramter
      if @spec.version.nil?
        puts "required field version was not found"
        exit 1
      end

      if @spec.version == "alpha1"
        # Getting rid of alpha1 syntax and just going to number syntax.  Will support this for a little bit...
        version = 1.0
      else

        number = Float( @spec.version ) rescue nil
        if number.nil? 
          puts "invalid value \"#{@spec.version}\" for version field of spec"
          exit 1
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
        puts "value of --deploy-type was #{@options[:deploy_kind]}, must be chronos, marathon or all"
        exit 1
      end
    end
  end
end
