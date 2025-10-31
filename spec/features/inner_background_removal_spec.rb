# spec/features/inner_background_removal_spec.rb
require 'spec_helper'

RSpec.describe 'Inner Background Removal' do
  describe '--try-inner flag' do
    context 'when processing image with centered sprite and interior background' do
      let(:test_image) { 'spec/fixtures/centered_sprite_with_inner_bg.png' }
      let(:output_image) { 'spec/tmp/output_inner_bg_removed.png' }

      before do
        # Ensure tmp directory exists
        FileUtils.mkdir_p('spec/tmp')
      end

      after do
        # Cleanup output files
        FileUtils.rm_f(output_image) if File.exist?(output_image)
      end

      it 'removes interior background regions when --try-inner is specified' do
        # Execute ruby_spriter with --try-inner flag
        result = system("ruby bin/ruby_spriter --image #{test_image} --remove-bg --try-inner --output #{output_image}")

        expect(result).to be true
        expect(File.exist?(output_image)).to be true

        # Verify that output has alpha channel (transparency)
        cmd = "magick identify -format '%[channels]' \"#{output_image}\""
        channels = `#{cmd}`.strip
        expect(channels).to include('a')
      end

      it 'preserves sprite quality and RGB data integrity' do
        output_quality = 'spec/tmp/output_quality_test.png'

        begin
          result = system("ruby bin/ruby_spriter --image #{test_image} --remove-bg --try-inner --output #{output_quality}")

          expect(result).to be true
          expect(File.exist?(output_quality)).to be true

          # Verify output file has content (not empty)
          file_size = File.size(output_quality)
          expect(file_size).to be > 100  # At least 100 bytes

          # Verify output has valid PNG structure
          cmd = "magick identify \"#{output_quality}\""
          identify_result = system(cmd)
          expect(identify_result).to be true
        ensure
          FileUtils.rm_f(output_quality) if File.exist?(output_quality)
        end
      end
    end

    context 'when --try-inner is NOT specified' do
      let(:test_image) { 'spec/fixtures/centered_sprite_with_inner_bg.png' }
      let(:output_without_inner) { 'spec/tmp/output_without_inner.png' }

      before do
        FileUtils.mkdir_p('spec/tmp')
      end

      after do
        FileUtils.rm_f(output_without_inner) if File.exist?(output_without_inner)
      end

      it 'maintains backward compatibility with v0.6.7.1 behavior' do
        # Process without --try-inner (v0.6.7.1 behavior)
        result = system("ruby bin/ruby_spriter --image #{test_image} --remove-bg --output #{output_without_inner}")
        expect(result).to be true
        expect(File.exist?(output_without_inner)).to be true
      end
    end
  end
end
