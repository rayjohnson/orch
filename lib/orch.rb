require "orch/version"
require 'hashie'
require 'json'
require 'thor'
require "yaml"
require "parse"
require "deploy"

module Orch
  class Application < Thor

    desc 'config', 'Interactive way to build ~/.orch/config.yml file'
    def config
      config = Orch::Config.new(options)

      if File.file?("#{Dir.home}/.orch/config.yml")
        say "This will over-write your existing ~/.orch/config.yaml file", :yellow
        answer = yes? "Proceed?", :yellow
        if answer == false
          exit 0
        end
      end
      say("Enter values to construct a ~/.orch/config.yaml file")
      marathon_url = ask("Marathon URL: ")
      chronos_url = ask("Chronos URL: ")

      config.setup_config(marathon_url, chronos_url)
    end

    option :deploy_type, :default => 'all',
           :desc => 'chronos, marathon, all'
    option :subst,
           :desc => 'KEY=VALUE substitute KEY with VALUE globaly in your config'
    option :show_json, :default => false,
           :desc => 'show the json result that would be sent to Chronos or Marathon'
    desc 'verify PATH', 'Checks basic syntax and does not deploy'
    def verify(file_name)
      parser = Orch::Parse.new(file_name, options)
      result = parser.parse(true)
      puts "Number of configs found: #{result.length}"
      result.each do |app|
        puts "Name: #{app[:name]}, Type: #{app[:type]}"
        if options[:show_json]
          pretty = JSON.pretty_generate(app[:json])
          puts "JSON: #{pretty}"
        end
      end
    end

    option :deploy_type, :default => 'all',
           :desc => 'chronos, marathon, all'
    option :chronos_url,
           :desc => 'url to chronos master'
    option :marathon_url,
           :desc => 'url to marathon master'
    option :subst,
           :desc => 'KEY=VALUE substitute KEY with VALUE globaly in your config'
    desc 'deploy PATH', 'Deploys config to mesos frameworks.'
    def deploy(file_name)
      parser = Orch::Parse.new(file_name, options)
      result = parser.parse(false)

      if result.length == 0
        puts "nothing found to deploy"
      end

      deploy = Orch::Deploy.new(options)
      result.each do |app|
        if app[:type] == "Chronos"
          deploy.deploy_chronos(app[:json])
        end
        if app[:type] == "Marathon"
          deploy.deploy_marathon(app[:json])
        end
        puts "deploy to #{app[:type]}"
        puts "#{app[:json]}"
      end
    end
  end
end
