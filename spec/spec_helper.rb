# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
end

require 'ruby_spriter'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Helpers for creating temp files in tests
  config.before(:suite) do
    @test_temp_dir = File.join(Dir.tmpdir, 'ruby_spriter_test')
    FileUtils.mkdir_p(@test_temp_dir)
  end

  config.after(:suite) do
    FileUtils.rm_rf(@test_temp_dir) if File.exist?(@test_temp_dir)
  end

  # Make test temp directory available to all specs
  config.before(:each) do
    @test_dir = File.join(@test_temp_dir, "test_#{Time.now.to_i}_#{rand(10000)}")
    FileUtils.mkdir_p(@test_dir)
  end

  config.after(:each) do
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
  end
end
