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

      it 'shows mode-specific help hints' do
        output = StringIO.new
        $stdout = output

        begin
          described_class.start(['--help'])
        rescue SystemExit
          # Expected
        ensure
          $stdout = STDOUT
        end

        expect(output.string).to include('Get mode-specific help:')
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

    describe '--overwrite flag' do
      it 'sets overwrite option to true' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:overwrite]).to eq(true)
          processor_double
        end

        described_class.start(['--video', 'test.mp4', '--overwrite'])
      end

      it 'defaults to false when not specified' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:overwrite]).to be_nil
          processor_double
        end

        described_class.start(['--video', 'test.mp4'])
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

      it 'works with --overwrite option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:image]).to eq(fixture_with_meta)
          expect(options[:remove_bg]).to eq(true)
          expect(options[:overwrite]).to eq(true)
          processor_double
        end

        described_class.start(['--image', fixture_with_meta, '--remove-bg', '--overwrite'])
      end

      it 'works with --overwrite and --output options combined' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:image]).to eq(fixture_with_meta)
          expect(options[:scale_percent]).to eq(50)
          expect(options[:output]).to eq('custom.png')
          expect(options[:overwrite]).to eq(true)
          processor_double
        end

        described_class.start(['--image', fixture_with_meta, '--scale', '50', '--output', 'custom.png', '--overwrite'])
      end
    end

    describe 'output filename behavior with processing' do
      it 'generates unique filename by default when processing without --output' do
        # Mock all dependencies
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!)
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_readable!)

        # Mock GimpProcessor to return a processed file
        gimp_double = instance_double(RubySpriter::GimpProcessor)
        allow(RubySpriter::GimpProcessor).to receive(:new).and_return(gimp_double)
        allow(gimp_double).to receive(:process).and_return('input-nobg-fuzzy_20251023_123456_789.png')

        processor = RubySpriter::Processor.new(
          image: fixture_with_meta,
          remove_bg: true,
          overwrite: false
        )

        allow(processor).to receive(:check_dependencies!)
        allow(processor).to receive(:setup_temp_directory)
        allow(processor).to receive(:cleanup)
        allow(processor).to receive(:gimp_path).and_return('/usr/bin/gimp')

        result = nil
        expect { result = processor.run }.to output(/SUCCESS/).to_stdout

        # Should return the uniquely-named file from GIMP processing
        expect(result[:output_file]).to match(/-nobg-fuzzy.*\.png$/)
      end

      it 'overwrites output file when --overwrite is specified' do
        # Mock all dependencies
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!)
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_readable!)

        # Mock GimpProcessor - with overwrite:true, it should return same filename
        gimp_double = instance_double(RubySpriter::GimpProcessor)
        allow(RubySpriter::GimpProcessor).to receive(:new).and_return(gimp_double)
        allow(gimp_double).to receive(:process).and_return('input-scaled-50pct.png')

        processor = RubySpriter::Processor.new(
          image: fixture_with_meta,
          scale_percent: 50,
          overwrite: true
        )

        allow(processor).to receive(:check_dependencies!)
        allow(processor).to receive(:setup_temp_directory)
        allow(processor).to receive(:cleanup)
        allow(processor).to receive(:gimp_path).and_return('/usr/bin/gimp')

        result = nil
        expect { result = processor.run }.to output(/SUCCESS/).to_stdout

        # Should return the base filename (no timestamp)
        expect(result[:output_file]).to eq('input-scaled-50pct.png')
      end

      it 'generates unique output filename when --output is used without --overwrite' do
        # Mock all dependencies
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!)
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_readable!)

        # Mock ensure_unique_output to verify it's called correctly
        allow(RubySpriter::Utils::FileHelper).to receive(:ensure_unique_output) do |path, overwrite:|
          expect(path).to eq('custom_output.png')
          expect(overwrite).to eq(false)
          'custom_output_20251023_123456_789.png'
        end

        # Mock GimpProcessor
        gimp_double = instance_double(RubySpriter::GimpProcessor)
        allow(RubySpriter::GimpProcessor).to receive(:new).and_return(gimp_double)
        allow(gimp_double).to receive(:process).and_return('temp-processed.png')

        # Mock file operations
        allow(FileUtils).to receive(:cp)

        processor = RubySpriter::Processor.new(
          image: fixture_with_meta,
          remove_bg: true,
          output: 'custom_output.png',
          overwrite: false
        )

        allow(processor).to receive(:check_dependencies!)
        allow(processor).to receive(:setup_temp_directory)
        allow(processor).to receive(:cleanup)
        allow(processor).to receive(:gimp_path).and_return('/usr/bin/gimp')

        result = nil
        expect { result = processor.run }.to output(/SUCCESS/).to_stdout

        # Should return unique filename
        expect(result[:output_file]).to match(/custom_output_\d{8}_\d{6}_\d{3}\.png$/)
      end

      it 'uses exact output filename when --output and --overwrite are both specified' do
        # Mock all dependencies
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!)
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_readable!)

        # Mock ensure_unique_output to verify it's called with overwrite:true
        allow(RubySpriter::Utils::FileHelper).to receive(:ensure_unique_output) do |path, overwrite:|
          expect(path).to eq('exact_output.png')
          expect(overwrite).to eq(true)
          'exact_output.png'
        end

        # Mock GimpProcessor
        gimp_double = instance_double(RubySpriter::GimpProcessor)
        allow(RubySpriter::GimpProcessor).to receive(:new).and_return(gimp_double)
        allow(gimp_double).to receive(:process).and_return('temp-processed.png')

        # Mock file operations
        allow(FileUtils).to receive(:cp)

        processor = RubySpriter::Processor.new(
          image: fixture_with_meta,
          scale_percent: 50,
          output: 'exact_output.png',
          overwrite: true
        )

        allow(processor).to receive(:check_dependencies!)
        allow(processor).to receive(:setup_temp_directory)
        allow(processor).to receive(:cleanup)
        allow(processor).to receive(:gimp_path).and_return('/usr/bin/gimp')

        result = nil
        expect { result = processor.run }.to output(/SUCCESS/).to_stdout

        # Should return exact filename (no timestamp)
        expect(result[:output_file]).to eq('exact_output.png')
      end

      it 'generates unique filename when using --sharpen alone without --output' do
        # Mock all dependencies
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!)
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_readable!)

        # Mock GimpProcessor to return a sharpened file
        gimp_double = instance_double(RubySpriter::GimpProcessor)
        allow(RubySpriter::GimpProcessor).to receive(:new).and_return(gimp_double)
        allow(gimp_double).to receive(:process).and_return('input-sharpened_20251023_123456_789.png')

        processor = RubySpriter::Processor.new(
          image: fixture_with_meta,
          sharpen: true,
          overwrite: false
        )

        allow(processor).to receive(:check_dependencies!)
        allow(processor).to receive(:setup_temp_directory)
        allow(processor).to receive(:cleanup)

        result = nil
        expect { result = processor.run }.to output(/SUCCESS/).to_stdout

        # Should return the uniquely-named sharpened file
        expect(result[:output_file]).to match(/-sharpened.*\.png$/)
      end

      it 'overwrites sharpened file when --sharpen with --overwrite' do
        # Mock all dependencies
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!)
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_readable!)

        # Mock GimpProcessor - with overwrite:true, should return base filename
        gimp_double = instance_double(RubySpriter::GimpProcessor)
        allow(RubySpriter::GimpProcessor).to receive(:new).and_return(gimp_double)
        allow(gimp_double).to receive(:process).and_return('input-sharpened.png')

        processor = RubySpriter::Processor.new(
          image: fixture_with_meta,
          sharpen: true,
          overwrite: true
        )

        allow(processor).to receive(:check_dependencies!)
        allow(processor).to receive(:setup_temp_directory)
        allow(processor).to receive(:cleanup)

        result = nil
        expect { result = processor.run }.to output(/SUCCESS/).to_stdout

        # Should return the base filename (no timestamp)
        expect(result[:output_file]).to eq('input-sharpened.png')
      end
    end
  end

  describe '--video flag' do
    let(:fixture_video) { File.join(__dir__, '..', 'fixtures', 'test_video.mp4') }

    describe 'context-sensitive help' do
      it 'shows video mode help with --help' do
        output = StringIO.new
        $stdout = output

        begin
          described_class.start(['--video', '--help'])
        rescue SystemExit
          # Expected
        ensure
          $stdout = STDOUT
        end

        expect(output.string).to include('Video Mode')
      end

      it 'shows parent-child option hierarchy in video mode help' do
        output = StringIO.new
        $stdout = output

        begin
          described_class.start(['--video', '--help'])
        rescue SystemExit
          # Expected
        ensure
          $stdout = STDOUT
        end

        # Check for parent options
        expect(output.string).to include('-s, --scale PERCENT')
        expect(output.string).to include('-r, --remove-bg')

        # Check for child options with hierarchy marker
        expect(output.string).to include('└─ Interpolation:')
        expect(output.string).to include('└─ Sharpen radius')
        expect(output.string).to include('└─ Use fuzzy select')
        expect(output.string).to include('└─ Feather radius')
        expect(output.string).to include('└─ Grow selection')

        # Check that --order mentions BOTH requirement
        expect(output.string).to match(/order.*BOTH.*--scale.*AND.*--remove-bg/i)
      end

      it 'shows --sharpen as standalone option in video mode help' do
        output = StringIO.new
        $stdout = output

        begin
          described_class.start(['--video', '--help'])
        rescue SystemExit
          # Expected
        ensure
          $stdout = STDOUT
        end

        # --sharpen should be a standalone parent option (not indented under --scale)
        expect(output.string).to match(/^  --sharpen\s+Apply unsharp mask/)

        # --sharpen modifiers should be children under --sharpen
        expect(output.string).to include('└─ Sharpen radius')
        expect(output.string).to include('└─ Sharpen gain')
        expect(output.string).to include('└─ Sharpen threshold')

        # --interpolation should ONLY be under --scale (not under --sharpen)
        lines = output.string.lines
        sharpen_line_idx = lines.index { |l| l.include?('--sharpen') && l.include?('Apply unsharp mask') }
        scale_line_idx = lines.index { |l| l.include?('--scale PERCENT') }
        interpolation_line_idx = lines.index { |l| l.include?('└─ Interpolation') }

        # Interpolation should come after scale, not after sharpen
        expect(interpolation_line_idx).to be > scale_line_idx
        expect(interpolation_line_idx).to be < sharpen_line_idx
      end
it 'includes --by-frame flag in video mode help' do
  output = StringIO.new
  $stdout = output

  begin
    described_class.start(['--video', '--help'])
  rescue SystemExit
    # Expected
  ensure
    $stdout = STDOUT
  end

  expect(output.string).to include('--by-frame')
  expect(output.string).to include('Remove background from each frame individually')
end

      it 'shows image mode help with --help' do
        output = StringIO.new
        $stdout = output

        begin
          described_class.start(['--image', '--help'])
        rescue SystemExit
          # Expected
        ensure
          $stdout = STDOUT
        end

        expect(output.string).to include('Image Mode')
      end

      it 'shows consolidate mode help with --help' do
        output = StringIO.new
        $stdout = output

        begin
          described_class.start(['--consolidate', '--help'])
        rescue SystemExit
          # Expected
        ensure
          $stdout = STDOUT
        end

        expect(output.string).to include('Consolidate Mode')
      end

      it 'shows batch mode help with --help' do
        output = StringIO.new
        $stdout = output

        begin
          described_class.start(['--batch', '--help'])
        rescue SystemExit
          # Expected
        ensure
          $stdout = STDOUT
        end

        expect(output.string).to include('Batch Mode')
      end
it 'includes --by-frame flag in batch mode help' do
  output = StringIO.new
  $stdout = output

  begin
    described_class.start(['--batch', '--help'])
  rescue SystemExit
    # Expected
  ensure
    $stdout = STDOUT
  end

  expect(output.string).to include('--by-frame')
  expect(output.string).to include('Remove background from each frame individually')
end

      it 'shows split mode help with --help' do
        output = StringIO.new
        $stdout = output

        begin
          described_class.start(['--split', '--help'])
        rescue SystemExit
          # Expected
        ensure
          $stdout = STDOUT
        end

        expect(output.string).to include('Split Mode')
      end
    end

    describe 'argument parsing' do
      it 'sets video option with --video flag' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          processor_double
        end

        described_class.start(['--video', fixture_video])
      end

      it 'supports short form -v flag' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          processor_double
        end

        described_class.start(['-v', fixture_video])
      end

      it 'accepts file path with spaces' do
        # Create a temp file with spaces in the name for this test
        temp_file = File.join(@test_dir, 'video with spaces.mp4')
        FileUtils.cp(fixture_video, temp_file)

        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(temp_file)
          processor_double
        end

        described_class.start(['--video', temp_file])
      end
    end

    describe 'mutual exclusivity with other input modes' do
      it 'cannot be used with --image' do
        expect do
          described_class.start(['--video', fixture_video, '--image', 'test.png'])
        end.to raise_error(RubySpriter::ValidationError, /Cannot use multiple input modes/)
      end

      it 'cannot be used with --consolidate' do
        expect do
          described_class.start(['--video', fixture_video, '--consolidate', 'a.png,b.png'])
        end.to raise_error(RubySpriter::ValidationError, /Cannot use multiple input modes/)
      end

      it 'cannot be used with --verify' do
        expect do
          described_class.start(['--video', fixture_video, '--verify', 'test.png'])
        end.to raise_error(RubySpriter::ValidationError, /Cannot use multiple input modes/)
      end

      it 'can be used alone without error' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)
        allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

        expect do
          described_class.start(['--video', fixture_video])
        end.not_to raise_error
      end
    end

    describe 'file validation' do
      describe 'file existence' do
        it 'raises error for non-existent file' do
          expect do
            described_class.start(['--video', 'nonexistent.mp4'])
          end.to raise_error(RubySpriter::ValidationError, /File not found/)
        end

        it 'accepts existing MP4 file' do
          processor_double = instance_double(RubySpriter::Processor)
          allow(processor_double).to receive(:run)
          allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

          expect(File.exist?(fixture_video)).to be true
          expect do
            described_class.start(['--video', fixture_video])
          end.not_to raise_error
        end
      end

      describe 'file extension validation' do
        it 'accepts .mp4 extension' do
          processor_double = instance_double(RubySpriter::Processor)
          allow(processor_double).to receive(:run)
          allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

          expect(File.extname(fixture_video)).to eq('.mp4')
          expect do
            described_class.start(['--video', fixture_video])
          end.not_to raise_error
        end

        it 'accepts .MP4 extension (case insensitive)' do
          # Create a temp file with uppercase extension
          temp_file = File.join(@test_dir, 'test.MP4')
          FileUtils.cp(fixture_video, temp_file)

          processor_double = instance_double(RubySpriter::Processor)
          allow(processor_double).to receive(:run)
          allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

          expect do
            described_class.start(['--video', temp_file])
          end.not_to raise_error
        end

        it 'rejects .avi extension' do
          temp_file = File.join(@test_dir, 'test.avi')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--video', temp_file])
          end.to raise_error(RubySpriter::ValidationError, /--video expects \.mp4 file, got: \.avi/)
        end

        it 'rejects .mov extension' do
          temp_file = File.join(@test_dir, 'test.mov')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--video', temp_file])
          end.to raise_error(RubySpriter::ValidationError, /--video expects \.mp4 file, got: \.mov/)
        end

        it 'rejects .mkv extension' do
          temp_file = File.join(@test_dir, 'test.mkv')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--video', temp_file])
          end.to raise_error(RubySpriter::ValidationError, /--video expects \.mp4 file, got: \.mkv/)
        end

        it 'rejects .wmv extension' do
          temp_file = File.join(@test_dir, 'test.wmv')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--video', temp_file])
          end.to raise_error(RubySpriter::ValidationError, /--video expects \.mp4 file, got: \.wmv/)
        end

        it 'rejects file with no extension' do
          temp_file = File.join(@test_dir, 'videofile')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--video', temp_file])
          end.to raise_error(RubySpriter::ValidationError, /--video expects \.mp4 file/)
        end
      end
    end

    describe 'integration with video-specific options' do
      it 'works with --frames option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:frame_count]).to eq(32)
          processor_double
        end

        described_class.start(['--video', fixture_video, '--frames', '32'])
      end

      it 'works with --columns option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:columns]).to eq(8)
          processor_double
        end

        described_class.start(['--video', fixture_video, '--columns', '8'])
      end

      it 'works with --width option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:max_width]).to eq(640)
          processor_double
        end

        described_class.start(['--video', fixture_video, '--width', '640'])
      end

      it 'works with --background option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:bg_color]).to eq('white')
          processor_double
        end

        described_class.start(['--video', fixture_video, '--background', 'white'])
      end

      it 'works with multiple video options combined' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:frame_count]).to eq(64)
          expect(options[:columns]).to eq(8)
          expect(options[:max_width]).to eq(480)
          expect(options[:bg_color]).to eq('white')
          processor_double
        end

        described_class.start([
          '--video', fixture_video,
          '--frames', '64',
          '--columns', '8',
          '--width', '480',
          '--background', 'white'
        ])
      end
    end

    describe 'integration with processing options' do
      it 'works with --scale option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:scale_percent]).to eq(50)
          processor_double
        end

        described_class.start(['--video', fixture_video, '--scale', '50'])
      end

      it 'works with --remove-bg option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:remove_bg]).to eq(true)
          processor_double
        end

        described_class.start(['--video', fixture_video, '--remove-bg'])
      end

      it 'works with --sharpen option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:sharpen]).to eq(true)
          processor_double
        end

        described_class.start(['--video', fixture_video, '--sharpen'])
      end

      it 'works with --interpolation option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:scale_interpolation]).to eq('lohalo')
          processor_double
        end

        described_class.start(['--video', fixture_video, '--interpolation', 'lohalo'])
      end

      it 'works with all options combined' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:frame_count]).to eq(32)
          expect(options[:columns]).to eq(8)
          expect(options[:scale_percent]).to eq(50)
          expect(options[:remove_bg]).to eq(true)
          expect(options[:sharpen]).to eq(true)
          expect(options[:scale_interpolation]).to eq('nohalo')
          processor_double
        end

        described_class.start([
          '--video', fixture_video,
          '--frames', '32',
          '--columns', '8',
          '--scale', '50',
          '--remove-bg',
          '--sharpen',
          '--interpolation', 'nohalo'
        ])
      end

      it 'works with --output option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:output]).to eq('custom_spritesheet.png')
          processor_double
        end

        described_class.start(['--video', fixture_video, '--output', 'custom_spritesheet.png'])
      end

      it 'works with --save-frames option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:save_frames]).to eq(true)
          processor_double
        end

        described_class.start(['--video', fixture_video, '--save-frames'])
      end
    end

    describe 'preset configurations' do
      it 'works with --preset thumbnail' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:columns]).to eq(3)
          expect(options[:frame_count]).to eq(9)
          expect(options[:max_width]).to eq(240)
          processor_double
        end

        described_class.start(['--video', fixture_video, '--preset', 'thumbnail'])
      end

      it 'works with --preset preview' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:columns]).to eq(4)
          expect(options[:frame_count]).to eq(16)
          expect(options[:max_width]).to eq(400)
          processor_double
        end

        described_class.start(['--video', fixture_video, '--preset', 'preview'])
      end

      it 'works with --preset detailed' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:columns]).to eq(10)
          expect(options[:frame_count]).to eq(50)
          expect(options[:max_width]).to eq(320)
          processor_double
        end

        described_class.start(['--video', fixture_video, '--preset', 'detailed'])
      end

      it 'works with --preset contact' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:video]).to eq(fixture_video)
          expect(options[:columns]).to eq(8)
          expect(options[:frame_count]).to eq(64)
          expect(options[:max_width]).to eq(160)
          processor_double
        end

        described_class.start(['--video', fixture_video, '--preset', 'contact'])
      end
    end
  end

  describe '--consolidate flag' do
    # Real spritesheets generated from test_video.mp4 using --video
    # These demonstrate the actual workflow: --video creates spritesheets, --consolidate combines them
    let(:spritesheet_4x2) { File.join(__dir__, '..', 'fixtures', 'spritesheet_4x2.png') }  # 2 cols, 2 rows, 4 frames
    let(:spritesheet_6x2) { File.join(__dir__, '..', 'fixtures', 'spritesheet_6x2.png') }  # 2 cols, 3 rows, 6 frames
    let(:spritesheet_4x4) { File.join(__dir__, '..', 'fixtures', 'spritesheet_4x4.png') }  # 4 cols, 1 row, 4 frames (different columns)

    # Generic PNG fixtures for edge case testing
    let(:fixture_with_meta) { File.join(__dir__, '..', 'fixtures', 'spritesheet_with_metadata.png') }
    let(:fixture_without_meta) { File.join(__dir__, '..', 'fixtures', 'image_without_metadata.png') }

    describe 'argument parsing' do
      it 'accepts comma-separated list of files' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:consolidate]).to eq([spritesheet_4x2, spritesheet_6x2])
          processor_double
        end

        described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}"])
      end

      it 'accepts three or more files' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:consolidate]).to eq([spritesheet_4x2, spritesheet_6x2, spritesheet_4x4])
          processor_double
        end

        described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2},#{spritesheet_4x4}"])
      end

      it 'accepts file paths with spaces' do
        # Create temp files with spaces in names
        temp_file1 = File.join(@test_dir, 'file with spaces 1.png')
        temp_file2 = File.join(@test_dir, 'file with spaces 2.png')
        FileUtils.cp(spritesheet_4x2, temp_file1)
        FileUtils.cp(spritesheet_6x2, temp_file2)

        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:consolidate]).to eq([temp_file1, temp_file2])
          processor_double
        end

        described_class.start(['--consolidate', "#{temp_file1},#{temp_file2}"])
      end
    end

    describe 'minimum file count validation' do
      it 'requires at least 2 files' do
        expect do
          described_class.start(['--consolidate', spritesheet_4x2])
        end.to raise_error(RubySpriter::ValidationError, /requires at least 2 files/)
      end

      it 'accepts exactly 2 files' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)
        allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

        expect do
          described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}"])
        end.not_to raise_error
      end

      it 'accepts more than 2 files' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)
        allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

        expect do
          described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2},#{spritesheet_4x4}"])
        end.not_to raise_error
      end
    end

    describe 'mutual exclusivity with other input modes' do
      it 'cannot be used with --video' do
        expect do
          described_class.start(['--video', 'test.mp4', '--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}"])
        end.to raise_error(RubySpriter::ValidationError, /Cannot use multiple input modes/)
      end

      it 'cannot be used with --image' do
        expect do
          described_class.start(['--image', spritesheet_4x2, '--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}"])
        end.to raise_error(RubySpriter::ValidationError, /Cannot use multiple input modes/)
      end

      it 'cannot be used with --verify' do
        expect do
          described_class.start(['--verify', spritesheet_4x2, '--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}"])
        end.to raise_error(RubySpriter::ValidationError, /Cannot use multiple input modes/)
      end

      it 'can be used alone without error' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)
        allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

        expect do
          described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}"])
        end.not_to raise_error
      end
    end

    describe 'file validation' do
      describe 'file existence' do
        it 'raises error if first file does not exist' do
          expect do
            described_class.start(['--consolidate', "nonexistent1.png,#{spritesheet_4x2}"])
          end.to raise_error(RubySpriter::ValidationError, /File not found/)
        end

        it 'raises error if second file does not exist' do
          expect do
            described_class.start(['--consolidate', "#{spritesheet_4x2},nonexistent2.png"])
          end.to raise_error(RubySpriter::ValidationError, /File not found/)
        end

        it 'raises error if any file in list does not exist' do
          expect do
            described_class.start(['--consolidate', "#{spritesheet_4x2},nonexistent.png,#{spritesheet_6x2}"])
          end.to raise_error(RubySpriter::ValidationError, /File not found/)
        end

        it 'accepts all existing spritesheet files' do
          processor_double = instance_double(RubySpriter::Processor)
          allow(processor_double).to receive(:run)
          allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

          expect(File.exist?(spritesheet_4x2)).to be true
          expect(File.exist?(spritesheet_6x2)).to be true

          expect do
            described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}"])
          end.not_to raise_error
        end
      end

      describe 'file extension validation' do
        it 'accepts all .png spritesheet files' do
          processor_double = instance_double(RubySpriter::Processor)
          allow(processor_double).to receive(:run)
          allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

          expect do
            described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}"])
          end.not_to raise_error
        end

        it 'accepts .PNG extension (case insensitive)' do
          temp_file1 = File.join(@test_dir, 'test1.PNG')
          temp_file2 = File.join(@test_dir, 'test2.PNG')
          FileUtils.cp(spritesheet_4x2, temp_file1)
          FileUtils.cp(spritesheet_6x2, temp_file2)

          processor_double = instance_double(RubySpriter::Processor)
          allow(processor_double).to receive(:run)
          allow(RubySpriter::Processor).to receive(:new).and_return(processor_double)

          expect do
            described_class.start(['--consolidate', "#{temp_file1},#{temp_file2}"])
          end.not_to raise_error
        end

        it 'rejects files with .jpg extension' do
          temp_file = File.join(@test_dir, 'test.jpg')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--consolidate', "#{spritesheet_4x2},#{temp_file}"])
          end.to raise_error(RubySpriter::ValidationError, /--consolidate expects \.png file, got: \.jpg/)
        end

        it 'rejects files with .mp4 extension' do
          temp_file = File.join(@test_dir, 'test.mp4')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--consolidate', "#{spritesheet_4x2},#{temp_file}"])
          end.to raise_error(RubySpriter::ValidationError, /--consolidate expects \.png file, got: \.mp4/)
        end

        it 'rejects files with no extension' do
          temp_file = File.join(@test_dir, 'noextension')
          FileUtils.touch(temp_file)

          expect do
            described_class.start(['--consolidate', "#{spritesheet_4x2},#{temp_file}"])
          end.to raise_error(RubySpriter::ValidationError, /--consolidate expects \.png file/)
        end

        it 'validates all files in the list' do
          temp_file1 = File.join(@test_dir, 'test1.jpg')
          temp_file2 = File.join(@test_dir, 'test2.gif')
          FileUtils.touch(temp_file1)
          FileUtils.touch(temp_file2)

          # Should fail on the first non-PNG file
          expect do
            described_class.start(['--consolidate', "#{spritesheet_4x2},#{temp_file1},#{temp_file2}"])
          end.to raise_error(RubySpriter::ValidationError, /--consolidate expects \.png file/)
        end
      end
    end

    describe 'consolidation-specific options' do
      it 'works with --validate-columns flag (default true)' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:consolidate]).to eq([spritesheet_4x2, spritesheet_6x2])
          expect(options[:validate_columns]).to eq(true)
          processor_double
        end

        described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}", '--validate-columns'])
      end

      it 'works with --no-validate-columns flag' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:consolidate]).to eq([spritesheet_4x2, spritesheet_6x2])
          expect(options[:validate_columns]).to eq(false)
          processor_double
        end

        described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}", '--no-validate-columns'])
      end
    end

    describe 'integration with other options' do
      it 'works with --output option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:consolidate]).to eq([spritesheet_4x2, spritesheet_6x2])
          expect(options[:output]).to eq('consolidated_output.png')
          processor_double
        end

        described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}", '--output', 'consolidated_output.png'])
      end

      it 'works with --debug option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:consolidate]).to eq([spritesheet_4x2, spritesheet_6x2])
          expect(options[:debug]).to eq(true)
          expect(options[:keep_temp]).to eq(true)
          processor_double
        end

        described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}", '--debug'])
      end

      it 'works with multiple options combined' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:consolidate]).to eq([spritesheet_4x2, spritesheet_6x2])
          expect(options[:validate_columns]).to eq(false)
          expect(options[:output]).to eq('combined.png')
          expect(options[:debug]).to eq(true)
          processor_double
        end

        described_class.start([
          '--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}",
          '--no-validate-columns',
          '--output', 'combined.png',
          '--debug'
        ])
      end

      it 'works with --overwrite option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:consolidate]).to eq([spritesheet_4x2, spritesheet_6x2])
          expect(options[:overwrite]).to eq(true)
          processor_double
        end

        described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}", '--overwrite'])
      end
    end

    describe 'default output filename behavior' do
      it 'generates consolidated_spritesheet.png when no --output specified' do
        # Mock all the dependencies
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!)
        allow(RubySpriter::Utils::FileHelper).to receive(:ensure_unique_output) do |path, overwrite:|
          expect(path).to eq('consolidated_spritesheet.png')
          expect(overwrite).to eq(false)
          'consolidated_spritesheet.png'
        end

        consolidator_double = instance_double(RubySpriter::Consolidator)
        allow(RubySpriter::Consolidator).to receive(:new).and_return(consolidator_double)
        allow(consolidator_double).to receive(:consolidate).and_return({
          output_file: 'consolidated_spritesheet.png',
          columns: 2,
          rows: 4,
          frames: 8
        })

        processor = RubySpriter::Processor.new(
          consolidate_mode: true,
          consolidate: [spritesheet_4x2, spritesheet_6x2],
          overwrite: false
        )

        allow(processor).to receive(:check_dependencies!)
        allow(processor).to receive(:setup_temp_directory)
        allow(processor).to receive(:cleanup)

        # Capture output to suppress console messages
        expect { processor.run }.to output(/SUCCESS/).to_stdout
      end

      it 'respects --overwrite flag with default filename' do
        # Mock all the dependencies
        allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!)
        allow(RubySpriter::Utils::FileHelper).to receive(:ensure_unique_output) do |path, overwrite:|
          expect(path).to eq('consolidated_spritesheet.png')
          expect(overwrite).to eq(true)
          'consolidated_spritesheet.png'
        end

        consolidator_double = instance_double(RubySpriter::Consolidator)
        allow(RubySpriter::Consolidator).to receive(:new).and_return(consolidator_double)
        allow(consolidator_double).to receive(:consolidate).and_return({
          output_file: 'consolidated_spritesheet.png',
          columns: 2,
          rows: 4,
          frames: 8
        })

        processor = RubySpriter::Processor.new(
          consolidate_mode: true,
          consolidate: [spritesheet_4x2, spritesheet_6x2],
          overwrite: true
        )

        allow(processor).to receive(:check_dependencies!)
        allow(processor).to receive(:setup_temp_directory)
        allow(processor).to receive(:cleanup)

        # Capture output to suppress console messages
        expect { processor.run }.to output(/SUCCESS/).to_stdout
      end
    end

    describe 'directory-based consolidation' do
      let(:test_dir) { File.join(@test_dir, 'consolidate_dir') }

      before do
        FileUtils.mkdir_p(test_dir)
        # Copy fixture spritesheets to test directory
        FileUtils.cp(spritesheet_4x2, File.join(test_dir, 'sprite1.png'))
        FileUtils.cp(spritesheet_6x2, File.join(test_dir, 'sprite2.png'))
      end

      it 'accepts --dir option with --consolidate' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:consolidate]).to be_nil
          expect(options[:dir]).to eq(test_dir)
          processor_double
        end

        described_class.start(['--consolidate', '--dir', test_dir])
      end

      it 'validates directory exists' do
        expect do
          described_class.start(['--consolidate', '--dir', 'nonexistent_directory'])
        end.to raise_error(RubySpriter::ValidationError, /Directory not found/)
      end

      it 'cannot use --dir with comma-separated file list' do
        expect do
          described_class.start(['--consolidate', "#{spritesheet_4x2},#{spritesheet_6x2}", '--dir', test_dir])
        end.to raise_error(RubySpriter::ValidationError, /Cannot use --dir with comma-separated file list/)
      end

      it 'works with --output option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:dir]).to eq(test_dir)
          expect(options[:output]).to eq('custom_output.png')
          processor_double
        end

        described_class.start(['--consolidate', '--dir', test_dir, '--output', 'custom_output.png'])
      end

      it 'works with --outputdir option' do
        output_dir = File.join(@test_dir, 'output')
        FileUtils.mkdir_p(output_dir)

        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:dir]).to eq(test_dir)
          expect(options[:outputdir]).to eq(output_dir)
          processor_double
        end

        described_class.start(['--consolidate', '--dir', test_dir, '--outputdir', output_dir])
      end

      it 'works with --overwrite option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:dir]).to eq(test_dir)
          expect(options[:overwrite]).to eq(true)
          processor_double
        end

        described_class.start(['--consolidate', '--dir', test_dir, '--overwrite'])
      end

      it 'works with --max-compress option' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:dir]).to eq(test_dir)
          expect(options[:max_compress]).to eq(true)
          processor_double
        end

        described_class.start(['--consolidate', '--dir', test_dir, '--max-compress'])
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

    describe '--split option' do
      it 'parses split option with R:C format' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:split]).to eq('4:4')
          processor_double
        end

        described_class.start(['--image', 'test.png', '--split', '4:4'])
      end
    end

    describe '--override-md option' do
      it 'sets override_md option to true' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:override_md]).to eq(true)
          processor_double
        end

        described_class.start(['--image', 'test.png', '--split', '4:4', '--override-md'])
      end
    end

    describe '--extract option' do
      it 'parses extract option with comma-separated frame numbers' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:extract]).to eq('1,2,4,5,8')
          processor_double
        end

        described_class.start(['--image', 'test.png', '--extract', '1,2,4,5,8'])
      end

      it 'allows duplicate frame numbers' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:extract]).to eq('1,1,2,2,3,3')
          processor_double
        end

        described_class.start(['--image', 'test.png', '--extract', '1,1,2,2,3,3'])
      end

      it 'cannot be used with --split' do
        expect do
          described_class.start(['--image', 'test.png', '--extract', '1,2,3', '--split', '4:4'])
        end.to raise_error(RubySpriter::ValidationError, /--extract and --split are mutually exclusive/)
      end
    end

    describe '--columns option' do
      it 'parses columns option for extraction grid' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:columns]).to eq(3)
          processor_double
        end

        described_class.start(['--image', 'test.png', '--extract', '1,2,3', '--columns', '3'])
      end

      it 'works without --extract (for future use)' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:columns]).to eq(5)
          processor_double
        end

        described_class.start(['--image', 'test.png', '--columns', '5'])
      end
    end

    describe '--save-frames option' do
      it 'sets save_frames option to true' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:save_frames]).to eq(true)
          processor_double
        end

        described_class.start(['--image', 'test.png', '--extract', '1,2,3', '--save-frames'])
      end

      it 'can be used without --extract' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:save_frames]).to eq(true)
          processor_double
        end

        described_class.start(['--image', 'test.png', '--split', '4:4', '--save-frames'])
      end
    end

    describe '--add-meta option' do
      it 'parses add-meta option with R:C format' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:add_meta]).to eq('4:4')
          processor_double
        end

        described_class.start(['--image', 'test.png', '--add-meta', '4:4'])
      end

      it 'cannot be combined with --scale' do
        expect do
          described_class.start(['--image', 'test.png', '--add-meta', '4:4', '--scale', '50'])
        end.to raise_error(RubySpriter::ValidationError, /--add-meta cannot be combined with processing options/)
      end

      it 'cannot be combined with --remove-bg' do
        expect do
          described_class.start(['--image', 'test.png', '--add-meta', '4:4', '--remove-bg'])
        end.to raise_error(RubySpriter::ValidationError, /--add-meta cannot be combined with processing options/)
      end

      it 'cannot be combined with --sharpen' do
        expect do
          described_class.start(['--image', 'test.png', '--add-meta', '4:4', '--sharpen'])
        end.to raise_error(RubySpriter::ValidationError, /--add-meta cannot be combined with processing options/)
      end
    end

    describe '--overwrite-meta option' do
      it 'sets overwrite_meta option to true' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:overwrite_meta]).to eq(true)
          processor_double
        end

        described_class.start(['--image', 'test.png', '--add-meta', '4:4', '--overwrite-meta'])
      end
    end

    describe '--frames option for partial grids' do
      it 'parses frames option with integer value' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:frame_count]).to eq(14)
          processor_double
        end

        described_class.start(['--image', 'test.png', '--add-meta', '4:4', '--frames', '14'])
      end
    end

    describe '--by-frame flag validation' do
      context 'when --by-frame is used without --video or --batch' do
        it 'raises ValidationError when used with --image' do
          expect {
            described_class.start(['--image', 'sprite.png', '--remove-bg', '--by-frame'])
          }.to raise_error(RubySpriter::ValidationError, /--by-frame requires --video or --batch/)
        end

        it 'raises ValidationError when used alone with --remove-bg' do
          expect {
            described_class.start(['--remove-bg', '--by-frame'])
          }.to raise_error(RubySpriter::ValidationError, /--by-frame requires --video or --batch/)
        end
      end

      context 'when --by-frame is used without --remove-bg' do
        it 'raises ValidationError' do
          expect {
            described_class.start(['--video', 'input.mp4', '--by-frame'])
          }.to raise_error(RubySpriter::ValidationError, /--by-frame requires --remove-bg/)
        end
      end

      context 'when --by-frame is used correctly' do
        it 'accepts --by-frame with --video and --remove-bg' do
          # Mock the entire Processor to prevent file validation
          mock_processor = instance_double(RubySpriter::Processor)
          allow(RubySpriter::Processor).to receive(:new).and_return(mock_processor)
          allow(mock_processor).to receive(:run)

          expect {
            described_class.start(['--video', 'input.mp4', '--remove-bg', '--by-frame'])
          }.not_to raise_error
        end

        it 'accepts --by-frame with --batch and --remove-bg' do
          # Mock the entire BatchProcessor to prevent directory validation
          mock_batch_processor = instance_double(RubySpriter::BatchProcessor)
          allow(RubySpriter::BatchProcessor).to receive(:new).and_return(mock_batch_processor)
          # Return a proper result hash that execute_batch_workflow expects
          allow(mock_batch_processor).to receive(:process).and_return({
            processed: 0,
            failed: 0,
            consolidated: false
          })

          expect {
            described_class.start(['--batch', '--dir', 'videos/', '--remove-bg', '--by-frame'])
          }.not_to raise_error
        end
      end
    end

    describe '--cleanup-cells flag validation' do
      it 'requires --remove-bg flag' do
        expect do
          described_class.start(['--video', 'test.mp4', '--cleanup-cells'])
        end.to raise_error(RubySpriter::ValidationError, /requires --remove-bg/)
      end

      it 'cannot be used with --by-frame' do
        expect do
          described_class.start(['--video', 'test.mp4', '--remove-bg', '--by-frame', '--cleanup-cells'])
        end.to raise_error(RubySpriter::ValidationError, /cannot be used with --by-frame/)
      end

      it 'requires video or batch mode' do
        # Create a temporary image file for testing
        temp_dir = Dir.mktmpdir
        temp_file = File.join(temp_dir, 'test.png')
        FileUtils.touch(temp_file)

        begin
          expect do
            described_class.start(['--image', temp_file, '--remove-bg', '--cleanup-cells'])
          end.to raise_error(RubySpriter::ValidationError, /requires --video or --batch/)
        ensure
          FileUtils.rm_rf(temp_dir)
        end
      end

      it 'validates cell-cleanup-threshold range (too low)' do
        expect do
          described_class.start(['--video', 'test.mp4', '--remove-bg', '--cleanup-cells', '--cell-cleanup-threshold', '0.5'])
        end.to raise_error(RubySpriter::ValidationError, /between 1.0 and 50.0/)
      end

      it 'validates cell-cleanup-threshold range (too high)' do
        expect do
          described_class.start(['--video', 'test.mp4', '--remove-bg', '--cleanup-cells', '--cell-cleanup-threshold', '55.0'])
        end.to raise_error(RubySpriter::ValidationError, /between 1.0 and 50.0/)
      end

      it 'accepts valid configuration' do
        processor_double = instance_double(RubySpriter::Processor)
        allow(processor_double).to receive(:run)

        allow(RubySpriter::Processor).to receive(:new) do |options|
          expect(options[:cleanup_cells]).to be true
          expect(options[:cell_cleanup_threshold]).to eq(20.0)
          processor_double
        end

        expect do
          described_class.start(['--video', 'test.mp4', '--remove-bg', '--cleanup-cells', '--cell-cleanup-threshold', '20.0'])
        end.not_to raise_error
      end
    end
  end
end
