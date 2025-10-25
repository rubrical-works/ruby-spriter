# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::Platform do
  describe '.current' do
    it 'returns a valid platform type' do
      expect([:windows, :linux, :macos, :unknown]).to include(described_class.current)
    end
  end

  describe '.windows?' do
    it 'returns boolean' do
      expect([true, false]).to include(described_class.windows?)
    end
  end

  describe '.linux?' do
    it 'returns boolean' do
      expect([true, false]).to include(described_class.linux?)
    end
  end

  describe '.macos?' do
    it 'returns boolean' do
      expect([true, false]).to include(described_class.macos?)
    end
  end

  describe '.default_gimp_path' do
    it 'returns a string path' do
      expect(described_class.default_gimp_path).to be_a(String)
    end

    it 'returns platform-appropriate path' do
      path = described_class.default_gimp_path
      
      if described_class.windows?
        expect(path).to match(/GIMP/)
        expect(path).to match(/\.exe$/)
      else
        expect(path).to start_with('/')
      end
    end
  end

  describe '.alternative_gimp_paths' do
    it 'returns an array' do
      expect(described_class.alternative_gimp_paths).to be_an(Array)
    end

    it 'contains only strings' do
      described_class.alternative_gimp_paths.each do |path|
        expect(path).to be_a(String)
      end
    end
  end

  describe '.imagemagick_convert_cmd' do
    it 'returns appropriate command for platform' do
      cmd = described_class.imagemagick_convert_cmd
      
      if described_class.windows?
        expect(cmd).to eq('magick convert')
      else
        expect(cmd).to eq('convert')
      end
    end
  end

  describe '.imagemagick_identify_cmd' do
    it 'returns appropriate command for platform' do
      cmd = described_class.imagemagick_identify_cmd

      if described_class.windows?
        expect(cmd).to eq('magick identify')
      else
        expect(cmd).to eq('identify')
      end
    end
  end

  describe '.detect_gimp_version' do
    it 'detects GIMP 3.x version from command output' do
      gimp3_output = "GNU Image Manipulation Program version 3.0.0"
      version = described_class.detect_gimp_version(gimp3_output)
      expect(version[:major]).to eq(3)
      expect(version[:minor]).to eq(0)
      expect(version[:full]).to eq('3.0.0')
    end
  end
end
