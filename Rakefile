require "bundler/gem_tasks"
require 'rake/testtask'
require 'fileutils'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = "test/**/test*.rb"
end

desc 'Clean up all built gems'
task :clean do
  FileUtils.rm_r Dir.glob('./pkg/*')
end

desc "Run tests"
task :default => :test
