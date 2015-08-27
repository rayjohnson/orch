require "orch/version"
require 'hashie'
require 'json'
require 'thor'
require "yaml"
require "parse"
require "chronos"
require "marathon"

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

    option :deploy_kind, :default => 'all',
           :desc => 'deploys only the given application kind: chronos, marathon, all'
    option :deploy_var, :default => 'all',
           :desc => 'DEPLOY_VAR=VALUE deploys only if a deploy_var matches the given value'
    option :subst,
           :desc => 'KEY=VALUE substitute KEY with VALUE globaly in your config'
    option :show_json, :default => false,
           :desc => 'show the json result that would be sent to Chronos or Marathon'
    option :server_verify, :default => true,
           :desc => 'verify the configuration against the server'
    desc 'verify PATH', 'Checks basic syntax and does not deploy'
    def verify(file_name)
      parser = Orch::Parse.new(file_name, options)
      result = parser.parse(true)
      puts "Number of configs found: #{result.length}"

      marathon = Orch::Marathon.new(options)
      chronos = Orch::Chronos.new(options)
      result.each do |app|
        printf "Name: %s, Type: %s, Deploy?: %s", app[:name], app[:type], app[:deploy]
        app[:env_vars].each do |key, value|
          printf ", %s: %s", key, value
        end
        printf "\n"
        if options[:show_json]
          pretty = JSON.pretty_generate(app[:json])
          puts "JSON: #{pretty}"
        end
        foundDiffs = false
        if (app[:type] == "Chronos") && (options[:server_verify] == true)
          foundDiffs = chronos.verify(app[:json].to_json)
        end
        if (app[:type] == "Marathon") && (options[:server_verify] == true)
          foundDiffs = marathon.verify(app[:json].to_json)
        end
        if (!foundDiffs) && (options[:server_verify] == true)
          puts "No differences with server found"
        end
      end
    end

    option :deploy_kind, :default => 'all',
           :desc => 'deploys only the given application kind: chronos, marathon, all'
    option :deploy_var, :default => 'all',
           :desc => 'DEPLOY_VAR=VALUE deploys only if a deploy_var matches the given value'
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

      marathon = Orch::Marathon.new(options)
      chronos = Orch::Chronos.new(options)
      result.each do |app|
        if !app[:deploy]
          puts "skipping app: #{app[:name]}"
          next
        end
        puts "deploying #{app[:name]} to #{app[:type]}"
        #puts "#{app[:json]}"  - should I support show_json here as well?
        if app[:type] == "Chronos"
          chronos.deploy(app[:json].to_json)
        end
        if app[:type] == "Marathon"
          marathon.deploy(app[:name], app[:json].to_json)
        end
      end
    end

    option :deploy_kind, :default => 'all',
           :desc => 'deletes only the given application kind: chronos, marathon, all'
    option :deploy_var, :default => 'all',
           :desc => 'DEPLOY_VAR=VALUE deletes only if a deploy_var matches the given value'
    option :chronos_url,
           :desc => 'url to chronos master'
    option :marathon_url,
           :desc => 'url to marathon master'
    option :subst,
           :desc => 'KEY=VALUE substitute KEY with VALUE globaly in your config'
    desc 'delete PATH', 'Deletes config from mesos frameworks.'
    def delete(file_name)
      parser = Orch::Parse.new(file_name, options)
      result = parser.parse(false)

      if result.length == 0
        puts "nothing found to delete"
      end

      marathon = Orch::Marathon.new(options)
      chronos = Orch::Chronos.new(options)
      result.each do |app|
        if !app[:deploy]
          puts "skipping app: #{app[:name]}"
          next
        end
        puts "deleting #{app[:name]} from #{app[:type]}"
        if app[:type] == "Chronos"
          chronos.delete(app[:name])
        end
        if app[:type] == "Marathon"
          marathon.delete(app[:name])
        end
      end
    end

    option :deploy_kind, :default => 'all',
           :desc => 'deletes only the given application kind: chronos, marathon, all'
    option :deploy_var, :default => 'all',
           :desc => 'DEPLOY_VAR=VALUE deletes only if a deploy_var matches the given value'
    option :marathon_url,
           :desc => 'url to marathon master'
    option :subst,
           :desc => 'KEY=VALUE substitute KEY with VALUE globaly in your config'
    desc 'restart PATH', 'Restarts specified application(s) on server'
    def restart(file_name)
      parser = Orch::Parse.new(file_name, options)
      result = parser.parse(false)

      if result.length == 0
        puts "nothing found to restart"
      end

      marathon = Orch::Marathon.new(options)
      result.each do |app|
        if !app[:deploy] || (app[:type] == "Chronos")
          puts "skipping app: #{app[:name]}"
          next
        end
        puts "restarting #{app[:name]} on #{app[:type]}"
        if app[:type] == "Marathon"
          marathon.restart(app[:name])
        end
      end
    end
  end
end
