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

  describe '--image flag' do
    let(:fixture_with_meta) { File.join(__dir__, '..', 'fixtures', 'spritesheet_with_metadata.png') }
    let(:fixture_without_meta) { File.join(__dir__, '..', 'fixtures', 'image_without_metadata.png') }

    describe 'argument parsing' do
      it 'sets image option with --image flag' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:image]).to eq(fixture_with_meta)
          processor_double
        end

        described_class.start(['--image', fixture_with_meta])
      end

      it 'supports short form -i flag' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:image]).to eq(fixture_without_meta)
          processor_double
        end

        described_class.start(['-i', fixture_without_meta])
      end

      it 'accepts file path with spaces' do
        # Create a temp file with spaces in the name for this test
        temp_file = File.join(@test_dir, 'file with spaces.png')
        FileUtils.cp(fixture_with_meta, temp_file)

        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:image]).to eq(temp_file)
          processor_double
        end

        described_class.start(['--image', temp_file])
      end
    end

    describe 'mutual exclusivity with other input modes' do
      it 'cannot be used with --video' do
        expect do
          described_class.start(['--video', 'test.mp4', '--image', fixture_with_meta])
        end.to raise_error(RubySpriter::ValidationError, /Cannot use multiple input modes/)
      end

      it 'cannot be used with --consolidate' do
        expect do
          described_class.start(['--consolidate', 'a.png,b.png', '--image', fixture_with_meta])
        end.to raise_error(RubySpriter::ValidationError, /Cannot use multiple input modes/)
      end

      it 'cannot be used with --verify' do
        expect do
          described_class.start(['--verify', fixture_with_meta, '--image', fixture_without_meta])
        end.to raise_error(RubySpriter::ValidationError, /Cannot use multiple input modes/)
      end

      it 'can be used alone without error' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)
        allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

        expect do
          described_class.start(['--image', fixture_with_meta])
        end.not_to raise_error
      end
    end

    describe 'file validation' do
      describe 'file existence' do
        it 'raises error for non-existent file' do
          expect do
            described_class.start(['--image', 'nonexistent.png'])
          end.to raise_error(RubySpriter::ValidationError, /File not found/)
        end

        it 'accepts existing PNG file with metadata' do
          processor_double = instance_double(RubySpriter::Processor)
          allow(processor_double).to receive(:run)
          allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

          expect(File.exist?(fixture_with_meta)).to be true
          expect do
            described_class.start(['--image', fixture_with_meta])
          end.not_to raise_error
        end

        it 'accepts existing PNG file without metadata' do
          processor_double = instance_double(RubySpriter::Processor)
          allow(processor_double).to receive(:run)
          allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

          expect(File.exist?(fixture_without_meta)).to be true
          expect do
            described_class.start(['--image', fixture_without_meta])
          end.not_to raise_error
        end
      end

      describe 'file extension validation' do
        it 'accepts .png extension' do
          processor_double = instance_double(RubySpriter::Processor)
          allow(processor_double).to receive(:run)
          allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

          expect(File.extname(fixture_with_meta)).to eq('.png')
          expect do
            described_class.start(['--image', fixture_with_meta])
          end.not_to raise_error
        end

        it 'accepts .PNG extension (case insensitive)' do
          # Create a temp file with uppercase extension
          temp_file = File.join(@test_dir, 'test.PNG')
          FileUtils.cp(fixture_with_meta, temp_file)

          processor_double = instance_double(RubySpriter::Processor)
          allow(processor_double).to receive(:run)
          allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

          expect do
            described_class.start(['--image', temp_file])
          end.not_to raise_error
        end

        it 'rejects .jpg extension' do
          # Create a fake .jpg file (doesn't need to be valid JPG for this test)
          temp_file = File.join(@test_dir, 'test.jpg')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--image', temp_file])
          end.to raise_error(RubySpriter::ValidationError, /--image expects \.png file, got: \.jpg/)
        end

        it 'rejects .jpeg extension' do
          temp_file = File.join(@test_dir, 'test.jpeg')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--image', temp_file])
          end.to raise_error(RubySpriter::ValidationError, /--image expects \.png file, got: \.jpeg/)
        end

        it 'rejects .gif extension' do
          temp_file = File.join(@test_dir, 'test.gif')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--image', temp_file])
          end.to raise_error(RubySpriter::ValidationError, /--image expects \.png file, got: \.gif/)
        end

        it 'rejects .bmp extension' do
          temp_file = File.join(@test_dir, 'test.bmp')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--image', temp_file])
          end.to raise_error(RubySpriter::ValidationError, /--image expects \.png file, got: \.bmp/)
        end

        it 'rejects file with no extension' do
          temp_file = File.join(@test_dir, 'testfile')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--image', temp_file])
          end.to raise_error(RubySpriter::ValidationError, /--image expects \.png file/)
        end
      end
    end

    describe 'integration with processing options' do
      it 'works with --scale option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:image]).to eq(fixture_with_meta)
          expect(options[:scale_percent]).to eq(50)
          processor_double
        end

        described_class.start(['--image', fixture_with_meta, '--scale', '50'])
      end

      it 'works with --remove-bg option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:image]).to eq(fixture_with_meta)
          expect(options[:remove_bg]).to eq(true)
          processor_double
        end

        described_class.start(['--image', fixture_with_meta, '--remove-bg'])
      end

      it 'works with --sharpen option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:image]).to eq(fixture_without_meta)
          expect(options[:sharpen]).to eq(true)
          processor_double
        end

        described_class.start(['--image', fixture_without_meta, '--sharpen'])
      end

      it 'works with --interpolation option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:image]).to eq(fixture_with_meta)
          expect(options[:scale_interpolation]).to eq('nohalo')
          processor_double
        end

        described_class.start(['--image', fixture_with_meta, '--interpolation', 'nohalo'])
      end

      it 'works with multiple processing options combined' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:image]).to eq(fixture_without_meta)
          expect(options[:scale_percent]).to eq(50)
          expect(options[:remove_bg]).to eq(true)
          expect(options[:sharpen]).to eq(true)
          expect(options[:scale_interpolation]).to eq('lohalo')
          processor_double
        end

        described_class.start([
          '--image', fixture_without_meta,
          '--scale', '50',
          '--remove-bg',
          '--sharpen',
          '--interpolation', 'lohalo'
        ])
      end

      it 'works with --output option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:image]).to eq(fixture_with_meta)
          expect(options[:output]).to eq('custom_output.png')
          processor_double
        end

        described_class.start(['--image', fixture_with_meta, '--output', 'custom_output.png'])
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
