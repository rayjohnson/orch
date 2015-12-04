require 'hashie'
require 'json'
require 'thor'
require "yaml"
require 'net/http'
require 'uri'

module Orch
  class Application < Thor

    desc 'config', 'Interactive way to build ~/.orch/config.yml file'
    def config
      $ORCH_CONFIG = Orch::Config.new(options)

      if File.file?("#{Dir.home}/.orch/config.yml")
        say "This will over-write your existing ~/.orch/config.yaml file", :yellow
        answer = yes? "Proceed?", :yellow
        exit 0 if answer == false
      end
      say("Enter values to construct a ~/.orch/config.yaml file")
      settings = {}
      settings["marathon_url"] = ask("Marathon URL: ")
      settings["chronos_url"] = ask("Chronos URL: ")
      settings["bamboo_url"] = ask("Bamboo URL: ")

      $ORCH_CONFIG.setup_config(settings)
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
    option :chronos_url,
           :desc => 'url to chronos master'
    option :marathon_url,
           :desc => 'url to marathon master'
    option :bamboo_url,
           :desc => 'url to bamboo server'
    desc 'verify PATH', 'Checks basic syntax, server configuration and does not deploy'
    def verify(file_name)
      $ORCH_CONFIG = Orch::Config.new(options)
      parser = Orch::Parse.new(file_name, options)
      result = parser.parse(true)

      numToDeploy = 0
      result.each do |app|
        numToDeploy += 1 if app[:deploy] == true
      end
      puts "Number of configs found: #{result.length} - #{numToDeploy} would deploy"

      marathon = Orch::Marathon.new
      chronos = Orch::Chronos.new
      bamboo = Orch::Bamboo.new
      result.each do |app|
        next if app[:deploy] == false
        printf "Name: %s, Type: %s", app[:name], app[:type]
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
          foundDiffs = chronos.verify(app[:url], app[:json].to_json)
        end
        if (app[:type] == "Marathon") && (options[:server_verify] == true)
          foundDiffs = marathon.verify(app[:url], app[:json].to_json)
          if app[:bamboo_spec]
            bambooDiffs = bamboo.verify(app[:bamboo_url], app[:name], app[:bamboo_spec])
            foundDiffs = foundDiffs || bambooDiffs
          end
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
    option :subst,
           :desc => 'KEY=VALUE substitute KEY with VALUE globaly in your config'
    option :chronos_url,
           :desc => 'url to chronos master'
    option :marathon_url,
           :desc => 'url to marathon master'
    option :bamboo_url,
           :desc => 'url to bamboo server'
    desc 'deploy PATH', 'Deploys application(s) to mesos frameworks.'
    def deploy(file_name)
      $ORCH_CONFIG = Orch::Config.new(options)
      parser = Orch::Parse.new(file_name, options)
      result = parser.parse(false)

      if result.length == 0
        puts "nothing found to deploy"
      end

      marathon = Orch::Marathon.new
      chronos = Orch::Chronos.new
      bamboo = Orch::Bamboo.new
      result.each do |app|
        if !app[:deploy]
          puts "skipping app: #{app[:name]}"
          next
        end
        puts "deploying #{app[:name]} to #{app[:type]}"
        #puts "#{app[:json]}"  - should I support show_json here as well?
        if app[:type] == "Chronos"
          chronos.deploy(app[:url], app[:json].to_json)
        end
        if app[:type] == "Marathon"
          marathon.deploy(app[:url], app[:name], app[:json].to_json)
          if app[:bamboo_spec]
            bamboo.deploy(app[:bamboo_url], app[:name], app[:bamboo_spec])
          end
        end
      end
    end

    option :deploy_kind, :default => 'all',
           :desc => 'deletes only the given application kind: chronos, marathon, all'
    option :deploy_var, :default => 'all',
           :desc => 'DEPLOY_VAR=VALUE deletes only if a deploy_var matches the given value'
    option :subst,
           :desc => 'KEY=VALUE substitute KEY with VALUE globaly in your config'
    option :chronos_url,
           :desc => 'url to chronos master'
    option :marathon_url,
           :desc => 'url to marathon master'
    option :bamboo_url,
           :desc => 'url to bamboo server'
    desc 'delete PATH', 'Deletes application(s) from mesos frameworks.'
    def delete(file_name)
      $ORCH_CONFIG = Orch::Config.new(options)
      parser = Orch::Parse.new(file_name, options)
      result = parser.parse(false)

      if result.length == 0
        puts "nothing found to delete"
      end

      marathon = Orch::Marathon.new
      chronos = Orch::Chronos.new
      bamboo = Orch::Bamboo.new

      result.each do |app|
        if !app[:deploy]
          puts "skipping app: #{app[:name]}"
          next
        end
        puts "deleting #{app[:name]} from #{app[:type]}"
        if app[:type] == "Chronos"
          chronos.delete(app[:url], app[:name])
        end
        if app[:type] == "Marathon"
          marathon.delete(app[:url], app[:name])
          if app[:bamboo_spec]
            bamboo.delete(app[:url], app[:name])
          end
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
      $ORCH_CONFIG = Orch::Config.new(options)
      parser = Orch::Parse.new(file_name, options)
      result = parser.parse(false)

      if result.length == 0
        puts "nothing found to restart"
      end

      marathon = Orch::Marathon.new
      result.each do |app|
        if !app[:deploy] || (app[:type] == "Chronos")
          puts "skipping app: #{app[:name]}"
          next
        end
        puts "restarting #{app[:name]} on #{app[:type]}"
        if app[:type] == "Marathon"
          marathon.restart(app[:url], app[:name])
        end
      end
    end
  end
end

require "orch/config"
require 'orch/util'
require "orch/parse"
require "orch/chronos"
require "orch/marathon"
require "orch/bamboo"
require "orch/version"

