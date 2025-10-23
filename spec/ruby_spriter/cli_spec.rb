# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::CLI do
  describe 'Other Options' do
    describe '--keep-temp flag' do
      it 'sets keep_temp option to true' do
        # Mock the Processor to capture the options
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:keep_temp]).to eq(true)
          processor_double
        end

        # Parse with --keep-temp and a valid input to avoid validation errors
        described_class.start(['--video', 'test.mp4', '--keep-temp'])
      end
    end

    describe '--debug flag' do
      it 'sets both debug and keep_temp options to true' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:debug]).to eq(true)
          expect(options[:keep_temp]).to eq(true)
          processor_double
        end

        described_class.start(['--video', 'test.mp4', '--debug'])
      end
    end

    describe '--help flag' do
      it 'outputs help text and exits' do
        expect do
          expect { described_class.start(['--help']) }.to output(/Usage: ruby_spriter/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'displays Other Options section' do
        expect do
          expect { described_class.start(['--help']) }.to output(/Other Options:/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'lists --keep-temp in help output' do
        expect do
          expect { described_class.start(['--help']) }.to output(/--keep-temp/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'lists --debug in help output' do
        expect do
          expect { described_class.start(['--help']) }.to output(/--debug/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'lists --version in help output' do
        expect do
          expect { described_class.start(['--help']) }.to output(/--version/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'lists --check-dependencies in help output' do
        expect do
          expect { described_class.start(['--help']) }.to output(/--check-dependencies/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'supports short form -h' do
        expect do
          expect { described_class.start(['-h']) }.to output(/Usage: ruby_spriter/).to_stdout
        end.to raise_error(SystemExit)
      end
    end

    describe '--version flag' do
      it 'outputs version information and exits' do
        expect do
          expect { described_class.start(['--version']) }
            .to output(/Ruby Spriter v#{RubySpriter::VERSION}/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'displays platform information' do
        expect do
          expect { described_class.start(['--version']) }
            .to output(/Platform:/).to_stdout
        end.to raise_error(SystemExit)
      end

      it 'displays date information' do
        expect do
          expect { described_class.start(['--version']) }
            .to output(/Date: #{RubySpriter::VERSION_DATE}/).to_stdout
        end.to raise_error(SystemExit)
      end
    end

    describe '--check-dependencies flag' do
      it 'sets check_dependencies option to true' do
        # Mock DependencyChecker to avoid actually checking dependencies
        checker_double = instance_double(RubySpriter::DependencyChecker)
        allow(checker_double).to receive(:print_report)
        allow(checker_double).to receive(:all_satisfied?).and_return(true)
        allow(RubySpriter::DependencyChecker).to receive(:new).and_return(checker_double)

        expect do
          described_class.start(['--check-dependencies'])
        end.to raise_error(SystemExit) { |error|
          expect(error.status).to eq(0)
        }
      end

      it 'exits with 0 when all dependencies are satisfied' do
        checker_double = instance_double(RubySpriter::DependencyChecker)
        allow(checker_double).to receive(:print_report)
        allow(checker_double).to receive(:all_satisfied?).and_return(true)
        allow(RubySpriter::DependencyChecker).to receive(:new).and_return(checker_double)

        expect do
          described_class.start(['--check-dependencies'])
        end.to raise_error(SystemExit) { |error|
          expect(error.status).to eq(0)
        }
      end

      it 'exits with 1 when dependencies are missing' do
        checker_double = instance_double(RubySpriter::DependencyChecker)
        allow(checker_double).to receive(:print_report)
        allow(checker_double).to receive(:all_satisfied?).and_return(false)
        allow(RubySpriter::DependencyChecker).to receive(:new).and_return(checker_double)

        expect do
          described_class.start(['--check-dependencies'])
        end.to raise_error(SystemExit) { |error|
          expect(error.status).to eq(1)
        }
      end

      it 'calls DependencyChecker with verbose: true' do
        checker_double = instance_double(RubySpriter::DependencyChecker)
        allow(checker_double).to receive(:print_report)
        allow(checker_double).to receive(:all_satisfied?).and_return(true)

        expect(RubySpriter::DependencyChecker).to receive(:new).with(verbose: true).and_return(checker_double)

        expect do
          described_class.start(['--check-dependencies'])
        end.to raise_error(SystemExit)
      end
    end
  end

  describe 'error handling' do
    describe 'invalid option' do
      it 'displays error message for invalid option' do
        expect do
          expect { described_class.start(['--invalid-option']) }
            .to output(/Error:.*invalid/).to_stdout
        end.to raise_error(SystemExit) { |error|
          expect(error.status).to eq(1)
        }
      end

      it 'suggests using --help' do
        expect do
          expect { described_class.start(['--invalid-option']) }
            .to output(/Use --help for usage information/).to_stdout
        end.to raise_error(SystemExit)
      end
    end
  end
end
