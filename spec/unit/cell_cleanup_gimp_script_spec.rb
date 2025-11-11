require 'spec_helper'
require_relative '../../lib/ruby_spriter/cell_cleanup_gimp_script'

RSpec.describe RubySpriter::CellCleanupGimpScript do
  describe '.generate_cleanup_script' do
    it 'generates valid GIMP 3.x Python-fu script' do
      script = described_class.generate_cleanup_script(
        '/input.png',
        '/output.png',
        ['rgb(255,0,0)']
      )

      expect(script).to include("from gi.repository import Gimp, Gio, Gegl")
      expect(script).to include('gimp-image-select-color')
      expect(script).to include('E:/input.png')
      expect(script).to include('E:/output.png')
    end

    it 'stores RGB colors as integers for later normalization' do
      script = described_class.generate_cleanup_script(
        '/input.png',
        '/output.png',
        ['rgb(255,0,0)']
      )

      # Red (255,0,0) should be stored as integers
      expect(script).to include("'r': 255")
      expect(script).to include("'g': 0")
      expect(script).to include("'b': 0")
    end

    it 'uses exact color matching (GIMP 3.x uses default threshold)' do
      script = described_class.generate_cleanup_script(
        '/input.png',
        '/output.png',
        ['rgb(255,0,0)']
      )

      # GIMP 3.x gimp-image-select-color does not have a threshold property
      # It uses the default color selection behavior
      expect(script).to include('gimp-image-select-color')
      expect(script).to include("'color', color")
    end

    it 'uses REPLACE for first color and ADD for subsequent colors' do
      script = described_class.generate_cleanup_script(
        '/input.png',
        '/output.png',
        ['rgb(255,0,0)', 'rgb(0,255,0)']
      )

      expect(script).to include('Gimp.ChannelOps.REPLACE')
      expect(script).to include('Gimp.ChannelOps.ADD')
      expect(script).to include("'r': 255")  # Red
      expect(script).to include("'r': 0")    # Green (no red)
    end
  end
end
