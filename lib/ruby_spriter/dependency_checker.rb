# frozen_string_literal: true

require 'open3'

module RubySpriter
  # Checks for required external dependencies
  class DependencyChecker
    REQUIRED_TOOLS = {
      ffmpeg: {
        command: 'ffmpeg -version',
        pattern: /ffmpeg version/i,
        install: {
          windows: 'choco install ffmpeg',
          linux: 'sudo apt install ffmpeg',
          macos: 'brew install ffmpeg'
        }
      },
      ffprobe: {
        command: 'ffprobe -version',
        pattern: /ffprobe version/i,
        install: {
          windows: 'Included with ffmpeg',
          linux: 'Included with ffmpeg',
          macos: 'Included with ffmpeg'
        }
      },
      imagemagick: {
        command: Platform.imagemagick_identify_cmd + ' -version',
        pattern: /ImageMagick/i,
        install: {
          windows: 'choco install imagemagick',
          linux: 'sudo apt install imagemagick',
          macos: 'brew install imagemagick'
        }
      },
      xvfb: {
        command: 'xvfb-run --help',
        pattern: /xvfb-run/i,
        install: {
          windows: 'Not required on Windows',
          linux: 'sudo apt install xvfb',
          macos: 'Not required on macOS'
        },
        optional_for: [:windows, :macos]  # Only required on Linux
      }
    }.freeze

    def initialize(verbose: false)
      @verbose = verbose
      @gimp_path = nil
      @gimp_version = nil
    end

    # Check all dependencies
    # @return [Hash] Results of dependency checks
    def check_all
      results = {}

      REQUIRED_TOOLS.each do |tool, config|
        results[tool] = check_tool(tool, config)
      end

      results[:gimp] = check_gimp
      results[:rembg] = check_rembg_with_optional_status

      results
    end

    # Check if all dependencies are satisfied
    # @return [Boolean] true if all dependencies are available
    def all_satisfied?
      results = check_all
      results.all? { |tool, status| status[:available] || status[:optional] }
    end

    # Print dependency status report
    def print_report
      results = check_all
      
      puts "\n" + "=" * 60
      puts "Dependency Check"
      puts "=" * 60
      
      results.each do |tool, status|
        # Determine icon based on availability and optional status
        if status[:optional] && !status[:available]
          icon = "⚪"
        else
          icon = status[:available] ? "✅" : "❌"
        end

        # Determine optional text
        if status[:optional]
          # Rembg is optional for all platforms, others may be platform-specific
          if tool == :rembg
            optional_text = " (Optional - required for --aggressive mode)"
          else
            optional_text = " (Optional for #{Platform.current})"
          end
        else
          optional_text = ""
        end

        puts "\n#{icon} #{tool.to_s.upcase}#{optional_text}"

        if status[:available]
          if tool == :gimp && status[:version]
            version_str = "GIMP #{status[:version][:full]}"
            puts "   Found: #{status[:path]}"
            puts "   Version: #{version_str}"
          elsif tool == :rembg
            puts "   Found: #{status[:path]}"
            puts "   Version: #{status[:version]}"
          else
            puts "   Found: #{status[:path] || status[:version]}"
          end
        else
          if status[:optional]
            if tool == :rembg
              puts "   Status: NOT FOUND (optional)"
              puts "   Install: #{status[:install_cmd]}"
            else
              puts "   Status: NOT FOUND (not required for this platform)"
            end
          else
            puts "   Status: NOT FOUND"
            puts "   Install: #{status[:install_cmd]}"
          end
        end
      end
      
      puts "\n" + "=" * 60 + "\n"
    end

    # Get the found GIMP executable path
    attr_reader :gimp_path

    # Get the detected GIMP version info
    attr_reader :gimp_version

    # Check for rembg availability
    # @return [Hash] Status hash with :available, :version, and :path keys
    def self.check_rembg
      begin
        # Try both "rembg" and "python -m rembg"
        stdout, stderr, status = Open3.capture3('rembg --version 2>&1')
        version_output = (stdout + stderr).strip

        if version_output.empty? || !status.success?
          stdout, stderr, status = Open3.capture3('python -m rembg --version 2>&1')
          version_output = (stdout + stderr).strip
        end

        if status.success? && !version_output.empty?
          # Parse version from output
          version = version_output.match(/\d+\.\d+\.\d+/)&.to_s || 'unknown'

          # Find path to rembg
          path_cmd = Platform.windows? ? 'where rembg 2>nul' : 'which rembg 2>/dev/null'
          path_stdout, _stderr, _status = Open3.capture3(path_cmd)
          path = path_stdout.strip

          { available: true, version: version, path: path }
        else
          { available: false, version: nil, path: nil }
        end
      rescue => e
        { available: false, version: nil, path: nil }
      end
    end

    private

    def check_tool(tool, config)
      # Check if this tool is optional for current platform
      optional_platforms = config[:optional_for] || []
      is_optional = optional_platforms.include?(Platform.current)

      stdout, stderr, status = Open3.capture3(config[:command])
      output = stdout + stderr

      if status.success? && output.match?(config[:pattern])
        version = extract_version(output)
        {
          available: true,
          version: version,
          install_cmd: nil,
          optional: is_optional
        }
      else
        {
          available: false,
          version: nil,
          install_cmd: config[:install][Platform.current],
          optional: is_optional
        }
      end
    rescue StandardError => e
      puts "DEBUG: Error checking #{tool}: #{e.message}" if @verbose
      {
        available: false,
        version: nil,
        install_cmd: config[:install][Platform.current],
        optional: is_optional
      }
    end

    def check_gimp
      # Try default path first
      default_path = Platform.default_gimp_path
      if gimp_exists?(default_path)
        @gimp_path = default_path
        @gimp_version = Platform.get_gimp_version(default_path)
        return gimp_status(true, default_path, @gimp_version)
      end

      # Try alternative paths
      Platform.alternative_gimp_paths.each do |path|
        if gimp_exists?(path)
          @gimp_path = path
          @gimp_version = Platform.get_gimp_version(path)
          return gimp_status(true, path, @gimp_version)
        end
      end

      # Not found
      gimp_status(false, nil, nil)
    end

    def gimp_exists?(path)
      return false if path.nil? || path.empty?

      # Handle Flatpak GIMP
      if path.start_with?('flatpak:')
        flatpak_app = path.sub('flatpak:', '')
        stdout, _stderr, status = Open3.capture3("flatpak list --app | grep #{flatpak_app}")
        return status.success? && !stdout.strip.empty?
      end

      File.exist?(path)
    end

    def gimp_status(available, path, version)
      status = {
        available: available,
        path: path,
        install_cmd: gimp_install_command
      }
      status[:version] = version if version
      status
    end

    def gimp_install_command
      case Platform.current
      when :windows
        'Download from https://www.gimp.org/downloads/ or use: choco install gimp'
      when :linux
        'sudo apt install gimp'
      when :macos
        'brew install gimp'
      else
        'Visit https://www.gimp.org/downloads/'
      end
    end

    def extract_version(output)
      # Try to extract version number from output
      if output =~ /version\s+(\d+\.\d+[\.\d]*)/i
        $1
      else
        output.lines.first&.strip || 'Unknown'
      end
    end

    def check_rembg_with_optional_status
      result = self.class.check_rembg
      # Mark rembg as optional (only needed for --aggressive mode)
      result[:optional] = true
      result[:install_cmd] = rembg_install_command unless result[:available]
      result
    end

    def rembg_install_command
      'pip install "rembg[cli]" (or python -m pip install "rembg[cli]" on Windows)'
    end
  end
end
