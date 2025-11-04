# frozen_string_literal: true

require 'spec_helper'
require 'ruby_spriter/threshold_stepper'
require 'ruby_spriter/gimp_processor'
require 'tempfile'

RSpec.describe RubySpriter::ThresholdStepper do
  let(:input_file) { Tempfile.new(['input', '.png']) }
  let(:output_file) { Tempfile.new(['output', '.png']) }
  let(:background_palette) do
    [
      { r: 255, g: 255, b: 255 },
      { r: 250, g: 250, b: 250 },
      { r: 245, g: 245, b: 245 }
    ]
  end
  let(:gimp_processor) { instance_double(RubySpriter::GimpProcessor) }
  let(:options) { { debug: false } }
  let(:stepper) do
    described_class.new(
      input_file.path,
      output_file.path,
      background_palette,
      gimp_processor,
      options
    )
  end

  after do
    input_file.close
    input_file.unlink
    output_file.close
    output_file.unlink
  end

  describe '#initialize' do
    it 'accepts background palette parameter' do
      expect(stepper.instance_variable_get(:@background_palette)).to eq(background_palette)
    end

    it 'accepts gimp_processor instance' do
      expect(stepper.instance_variable_get(:@gimp_processor)).to eq(gimp_processor)
    end

    it 'uses default threshold values' do
      thresholds = stepper.instance_variable_get(:@threshold_values)
      expect(thresholds).to eq([0.0, 0.5, 1.0, 3.0, 5.0, 10.0])
    end

    it 'accepts custom threshold values' do
      custom_stepper = described_class.new(
        input_file.path,
        output_file.path,
        background_palette,
        gimp_processor,
        { threshold_values: [1.0, 5.0, 10.0] }
      )

      thresholds = custom_stepper.instance_variable_get(:@threshold_values)
      expect(thresholds).to eq([1.0, 5.0, 10.0])
    end
  end

  describe '#process' do
    it 'generates GIMP script for each threshold value' do
      # Mock GIMP processor to track script executions
      script_calls = []
      allow(gimp_processor).to receive(:execute_python_script) do |script, temp_output|
        script_calls << { script: script, output: temp_output }
        true
      end

      # Mock ImageMagick compositing
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      stepper.process

      # Should generate 6 scripts (one per default threshold)
      expect(script_calls.length).to eq(6)
    end

    it 'includes background palette colors in GIMP script' do
      generated_script = nil
      allow(gimp_processor).to receive(:execute_python_script) do |script, _|
        generated_script = script
        true
      end

      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      stepper.process

      # Script should reference the background colors (normalized to 0.0-1.0)
      # Background palette has: {r: 255, g: 255, b: 255}, {r: 250, g: 250, b: 250}, {r: 245, g: 245, b: 245}
      # These become: rgb(1.0, 1.0, 1.0), rgb(0.98..., 0.98..., 0.98...), rgb(0.96..., 0.96..., 0.96...)
      expect(generated_script).to include('Gegl.Color.new')  # Uses Gegl.Color
      expect(generated_script).to include('rgb(')  # RGB format
      expect(generated_script).to match(/rgb\(1\.0, 1\.0, 1\.0\)/)  # First color (255,255,255)
    end

    it 'uses gimp-image-select-color in generated script' do
      generated_script = nil
      allow(gimp_processor).to receive(:execute_python_script) do |script, _|
        generated_script = script
        true
      end

      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      stepper.process

      # Script should use the correct GIMP procedure
      expect(generated_script).to include('gimp-image-select-color')
    end

    it 'applies threshold parameter in GIMP script' do
      generated_scripts = []
      allow(gimp_processor).to receive(:execute_python_script) do |script, _|
        generated_scripts << script
        true
      end

      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      stepper.process

      # Each script should have a different threshold value
      expect(generated_scripts[0]).to include('threshold')
      expect(generated_scripts[1]).to include('threshold')
    end

    it 'composites threshold results with ImageMagick' do
      allow(gimp_processor).to receive(:execute_python_script).and_return(true)

      composite_calls = []
      allow(Open3).to receive(:capture3) do |cmd|
        composite_calls << cmd if cmd.include?('magick')
        ['', '', double(success?: true)]
      end

      stepper.process

      # Should composite the results
      expect(composite_calls.length).to be > 0
    end
  end

  describe 'timeout handling' do
    it 'skips threshold on per-threshold timeout' do
      call_count = 0
      allow(gimp_processor).to receive(:execute_python_script) do
        call_count += 1
        if call_count == 2
          # Simulate timeout on second threshold
          sleep 0.1
          raise Timeout::Error, 'Threshold processing timeout'
        end
        true
      end

      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      # Should not raise error, just skip the threshold
      expect { stepper.process }.not_to raise_error
    end

    it 'reports skipped thresholds' do
      allow(gimp_processor).to receive(:execute_python_script) do
        raise Timeout::Error, 'Threshold processing timeout'
      end

      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      stepper.process
      report = stepper.report

      expect(report[:skipped_thresholds]).to be > 0
    end
  end

  describe '#report' do
    it 'includes processing statistics' do
      allow(gimp_processor).to receive(:execute_python_script).and_return(true)
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      stepper.process
      report = stepper.report

      expect(report).to have_key(:thresholds_processed)
      expect(report).to have_key(:skipped_thresholds)
      expect(report).to have_key(:total_time)
    end
  end
end
