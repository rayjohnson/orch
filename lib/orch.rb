require "orch/version"
require 'hashie'
require 'thor'
require "yaml"
require "parse"
require "deploy"

module Orch
  class Application < Thor

    option :deploy_type, :default => 'all',
           :desc => 'chronos, marathon, all'
    desc 'verify PATH', 'Checks syntax and does not deploy'
    def verify(file_name)
      parser = Orch::Parse.new(file_name, options)
      result = parser.parse(true)
      result.each do |app|
        puts "#{app[:success]}"
        puts "deploy to #{app[:type]}"
        puts "#{app[:json]}"
      end
    end

    option :deploy_type, :default => 'all',
           :desc => 'chronos, marathon, all'
    option :chronos_url,
           :desc => 'url to chronos master'
    desc 'deploy PATH', 'Deploys config to mesos.  TODO write more'
    def deploy(file_name)
      parser = Orch::Parse.new(file_name, options)
      result = parser.parse(false)

      if result.length == 0
        puts "nothing found to deploy"
      end

      deploy = Orch::Deploy.new(options)
      result.each do |app|
        if app[:type] == :chronos
          deploy.deploy_chronos(app[:json])
        end
        puts "deploy to #{app[:type]}"
        puts "#{app[:json]}"
      end
    end
  end
end
