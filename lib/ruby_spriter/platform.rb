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
        '/opt/gimp/bin/gimp',
        'flatpak:org.gimp.GIMP'  # Flatpak GIMP
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

      # Detect GIMP version from version string output
      # @param version_output [String] Output from gimp --version command
      # @return [Hash] Version information with :major, :minor, :patch, :full keys, or nil if parse fails
      def detect_gimp_version(version_output)
        return nil if version_output.nil? || version_output.empty?

        # Match version pattern: "version X.Y.Z" or "version X.Y"
        match = version_output.match(/version\s+(\d+)\.(\d+)(?:\.(\d+))?/i)
        return nil unless match

        {
          major: match[1].to_i,
          minor: match[2].to_i,
          patch: match[3]&.to_i || 0,
          full: match[1..3].compact.join('.')
        }
      end

      # Get GIMP version from executable path
      # @param gimp_path [String] Path to GIMP executable or flatpak:app.id
      # @return [Hash] Version information, or nil if detection fails
      def get_gimp_version(gimp_path)
        return nil if gimp_path.nil? || gimp_path.empty?

        require 'open3'

        # Handle Flatpak GIMP
        if gimp_path.start_with?('flatpak:')
          flatpak_app = gimp_path.sub('flatpak:', '')
          stdout, stderr, status = Open3.capture3("flatpak run #{flatpak_app} --version")
          return nil unless status.success?
          return detect_gimp_version(stdout + stderr)
        end

        return nil unless File.exist?(gimp_path)

        stdout, stderr, status = Open3.capture3("#{quote_path_simple(gimp_path)} --version")
        return nil unless status.success?

        detect_gimp_version(stdout + stderr)
      rescue StandardError
        nil
      end

      private

      # Simple path quoting helper for Platform module
      def quote_path_simple(path)
        return path unless path.include?(' ')
        windows? ? "\"#{path}\"" : "'#{path}'"
      end
    end
  end
end
