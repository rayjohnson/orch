require 'yaml'
require 'json'

module Orch
  class Parse

    def initialize(path, options)
      if ! File.file?(path)
        puts "file does not exist: #{path}"
        exit 1
      end
      # TODO: try resecue for any syntax issues in yaml file
      begin
        yaml = ::YAML.load_file(path)
      rescue Psych::SyntaxError => e
        puts "error parsing yaml file #{e}"
        exit 1
      end
      #puts yaml.to_json

      @options = options

      @spec = Hashie::Mash.new(yaml)
    end

    def parse(dry_run)
      @dry_run = dry_run
      check_option_syntax
      spec = @spec

      # Check for valid version paramter
      if spec.version.nil?
        puts "required field version was not found"
        exit 1
      end
      if spec.version != "alpha1"
        puts "unsupported orch version specified: #{spec.version}"
        puts "application only understands version alpha1"
        exit 1
      end

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
            puts "environments_var #{key} specified - but not included in app"
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

      # Augment any spec environment variables with meta values
      if chronos_spec.environmentVariables.nil?
        chronos_spec.environmentVariables = []
      end
      env_var_values.each do |key, value|
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

      # Augment any spec environment variables with meta values
      env_var_values.each do |key, value|
        marathon_spec.env[key] = value     
      end

      spec_str = do_subst(marathon_spec, app)
      marathon_spec = JSON.parse(spec_str)

      return marathon_spec
    end

    def should_deploy?(app)
      result = true
      if (app.kind == "Marathon") && @options[:deploy_kind] == 'chronos'
        result = false
      end
      if (app.kind == "Chronos") && @options[:deploy_kind] == 'marathon'
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

      return spec_str
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
