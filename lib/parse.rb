require 'yaml'
require 'json'

module Orch
  class Parse
    attr_accessor :filter

    def initialize(path, options)
      if ! File.file?(path)
        puts "file does not exist: #{path}"
        exit 1
      end
      # TODO: try resecue for any syntax issues in yaml file
      yaml = ::YAML.load_file(path)

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
        exit 1
      end

      # Does this config support environments
      @hasEnvironments = false
      defined_environments = {}
      if (! spec.environments.nil?)
        @hasEnvironments = true
        spec.environments.each do |e|
          defined_environments[e] = e
          puts "Env: #{e}"
        end
      end

      if (! spec.environments_var.nil?)
        puts "has environments var: #{spec.environments_var}"
        @environments_var = spec.environments_var
      end

      if spec.applications.nil?
        puts "required section applications: must have at least one application defined"
        exit 1
      end

      results = []
      spec.applications.each do |app|
        # Check for valid kind paramter
        if app.kind.nil?
          puts "required field kind was not found"
          exit 1
        end


        if !(app.kind == "Chronos" || app.kind == "Marathon")
          puts "unsupported kind specified: #{app.kind} - must be: Chronos | Marathon"
          exit 1
        end

        if !(@hasEnvironments && defined_environments.has_key?(app.environment))
          puts "environment \"#{app.environment}\" not defined in environments"
          exit 1
        end

        if (app.kind == "Chronos") && do_chronos?
          puts "parsing chronos"
          chronos_spec = parse_chronos(app)
          result = {:success => true, :type => :chronos, :json => chronos_spec.to_json}
          results << result
        end
      end

      return results
    end

    def parse_chronos(app)
      # TODO: check if it exists
      cronos_spec = app.cronos_spec

      # This adds environment vaiables to the spec that conform to our docker-wrapper security hack
      if ! app.vault.nil?
        # TODO: check that an environment was defined
        if (! @hasEnvironments) || app.environment.nil?
          puts "the vault feature requires an environment to be set"
          exit 1
        end

        count = 1
        cronos_spec.environmentVariables ||= []
        app.vault.each do |vault_key|
          # Add an environment
          pair = {"name" => "VAULT_KEY_#{count}", "value" => vault_key}
          count += 1
          cronos_spec.environmentVariables << pair
        end
      end

      if (! @environments_var.nil?)
        pair = {"name" => @environments_var, "value" => app.environment}
        cronos_spec.environmentVariables << pair
      end

      return cronos_spec
    end

    def do_chronos?
      return ['chronos', 'all'].include?(@options[:deploy_type])
    end

    def check_option_syntax
      if @dry_run
        return
      end

      if ! ['chronos', 'marathon', 'all'].include?(@options[:deploy_type])
        puts "value of --deploy-type was #{@options[:deploy_type]}, must be chronos, marathon or all"
        exit 1
      end
    end
  end
end
