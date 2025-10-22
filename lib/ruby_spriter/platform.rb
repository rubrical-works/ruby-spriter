# frozen_string_literal: true

module RubySpriter
  # Platform detection and configuration
  class Platform
    PLATFORM_TYPE = case RUBY_PLATFORM
                    when /mingw|mswin|windows/i then :windows
                    when /linux/i then :linux
                    when /darwin/i then :macos
                    else :unknown
                    end

    # GIMP executable paths by platform
    GIMP_DEFAULT_PATHS = {
      windows: 'C:\\Program Files\\GIMP 3\\bin\\gimp-console-3.0.exe',
      linux: '/usr/bin/gimp',
      macos: '/Applications/GIMP.app/Contents/MacOS/gimp'
    }.freeze

    # Alternative GIMP paths to search
    GIMP_ALTERNATIVE_PATHS = {
      windows: [
        'C:\\Program Files\\GIMP 3\\bin\\gimp-console-3.0.exe',
        'C:\\Program Files (x86)\\GIMP 3\\bin\\gimp-console-3.0.exe',
        'C:\\Program Files\\GIMP 2\\bin\\gimp-console-2.10.exe',
        'C:\\Program Files (x86)\\GIMP 2\\bin\\gimp-console-2.10.exe'
      ].freeze,
      linux: [
        '/usr/bin/gimp',
        '/usr/local/bin/gimp',
        '/snap/bin/gimp',
        '/opt/gimp/bin/gimp'
      ].freeze,
      macos: [
        '/Applications/GIMP.app/Contents/MacOS/gimp',
        '/Applications/GIMP-2.10.app/Contents/MacOS/gimp'
      ].freeze
    }.freeze

    class << self
      # Get the current platform type
      def current
        PLATFORM_TYPE
      end

      # Check if running on Windows
      def windows?
        PLATFORM_TYPE == :windows
      end

      # Check if running on Linux
      def linux?
        PLATFORM_TYPE == :linux
      end

      # Check if running on macOS
      def macos?
        PLATFORM_TYPE == :macos
      end

      # Get default GIMP path for current platform
      def default_gimp_path
        GIMP_DEFAULT_PATHS[PLATFORM_TYPE]
      end

      # Get alternative GIMP paths for current platform
      def alternative_gimp_paths
        GIMP_ALTERNATIVE_PATHS[PLATFORM_TYPE] || []
      end

      # Get ImageMagick convert command name
      def imagemagick_convert_cmd
        windows? ? 'magick convert' : 'convert'
      end

      # Get ImageMagick identify command name
      def imagemagick_identify_cmd
        windows? ? 'magick identify' : 'identify'
      end
    end
  end
end
