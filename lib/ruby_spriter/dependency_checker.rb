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
      }
    }.freeze

    def initialize(verbose: false)
      @verbose = verbose
      @gimp_path = nil
    end

    # Check all dependencies
    # @return [Hash] Results of dependency checks
    def check_all
      results = {}
      
      REQUIRED_TOOLS.each do |tool, config|
        results[tool] = check_tool(tool, config)
      end

      results[:gimp] = check_gimp

      results
    end

    # Check if all dependencies are satisfied
    # @return [Boolean] true if all dependencies are available
    def all_satisfied?
      results = check_all
      results.all? { |_tool, status| status[:available] }
    end

    # Print dependency status report
    def print_report
      results = check_all
      
      puts "\n" + "=" * 60
      puts "Dependency Check"
      puts "=" * 60
      
      results.each do |tool, status|
        icon = status[:available] ? "✅" : "❌"
        puts "\n#{icon} #{tool.to_s.upcase}"
        
        if status[:available]
          puts "   Found: #{status[:path] || status[:version]}"
        else
          puts "   Status: NOT FOUND"
          puts "   Install: #{status[:install_cmd]}"
        end
      end
      
      puts "\n" + "=" * 60 + "\n"
    end

    # Get the found GIMP executable path
    attr_reader :gimp_path

    private

    def check_tool(tool, config)
      stdout, stderr, status = Open3.capture3(config[:command])
      output = stdout + stderr

      if status.success? && output.match?(config[:pattern])
        version = extract_version(output)
        {
          available: true,
          version: version,
          install_cmd: nil
        }
      else
        {
          available: false,
          version: nil,
          install_cmd: config[:install][Platform.current]
        }
      end
    rescue StandardError => e
      puts "DEBUG: Error checking #{tool}: #{e.message}" if @verbose
      {
        available: false,
        version: nil,
        install_cmd: config[:install][Platform.current]
      }
    end

    def check_gimp
      # Try default path first
      default_path = Platform.default_gimp_path
      if gimp_exists?(default_path)
        @gimp_path = default_path
        return gimp_status(true, default_path)
      end

      # Try alternative paths
      Platform.alternative_gimp_paths.each do |path|
        if gimp_exists?(path)
          @gimp_path = path
          return gimp_status(true, path)
        end
      end

      # Not found
      gimp_status(false, nil)
    end

    def gimp_exists?(path)
      return false if path.nil? || path.empty?
      File.exist?(path)
    end

    def gimp_status(available, path)
      {
        available: available,
        path: path,
        install_cmd: gimp_install_command
      }
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
  end
end
