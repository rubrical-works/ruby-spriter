# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc 'Run tests'
task default: :spec

desc 'Run tests with coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['spec'].execute
end

desc 'Run RuboCop and RSpec'
task test: %i[rubocop spec]

desc 'Check dependency status'
task :check_deps do
  require_relative 'lib/ruby_spriter'
  checker = RubySpriter::DependencyChecker.new(verbose: true)
  checker.print_report
  
  unless checker.all_satisfied?
    puts "\n⚠️  Some dependencies are missing!"
    exit 1
  end
  
  puts "\n✅ All dependencies satisfied!"
end
