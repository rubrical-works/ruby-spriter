# Ruby Spriter v0.7.0.1 Requirements 

Requirements Revision #: 11
Release Type: PATCH RELEASE (builds upon v0.7.0)
Status: IN PROGRESS - Cell-Based Cleanup Added
Date: 2025-11-10
Prerequisite: Upload this requirements document directly or through the TypingMind KB as a direct file upload.

***

## Performance Optimization (COMPLETED)

**Status:** ✅ COMPLETE (2025-11-05)

[Previous content remains the same...]

***

## Feature: Frame-by-Frame Background Removal (COMPLETED)

**Status:** ✅ COMPLETE (2025-11-07)

[Previous content remains the same...]

***

## Feature: Cell-Based Background Cleanup (NEW - IN SCOPE FOR v0.7.0.1)

**Status:** ⚠️ IMPLEMENTED BUT REQUIRES OPTIMIZATION (2025-11-11)

**Objective:** Add intelligent cell-based background cleanup for finished spritesheets with residual background pixels that vary across cells. Provides faster alternative to `--by-frame` for videos with varying backgrounds.

**Implementation Note:** Feature is technically complete with all core components implemented and tested (512/512 tests passing). CLI execution works correctly, cell analysis functions as designed, and GIMP integration is operational. However, the feature does not effectively remove residual backgrounds in practice and requires algorithm refinement and performance optimization before production use.

### Problem Statement

After standard background removal on assembled spritesheets, residual background pixels often remain when background colors vary significantly across frames:
- Example: Character moves from green forest → blue ocean → red desert
- Single edge sampling cannot capture all color variations
- Result: Some cells retain residual background pixels

**Current Solutions:**
1. **`--remove-bg` alone**: Fast but may miss residual backgrounds
2. **`--by-frame`**: Thorough but slow (~120 sec for 32 frames - extracts/processes/reassembles)

**Gap:** Need a middle ground that is both fast AND thorough.

### Solution Design

**Approach:** Cell-by-cell analysis AFTER standard background removal:

1. Divide spritesheet into grid cells (we know MxN dimensions)
2. For each cell:
   - Extract all unique colors with pixel counts (ImageMagick histogram)
   - Calculate percentage of each color vs total non-transparent pixels
   - Identify "dominant" colors exceeding threshold (default: 15%)
   - If dominant colors found → apply GIMP color selection to remove them
   - If no dominant colors → skip cell (likely all sprite)
3. Reassemble cleaned cells into final spritesheet

**Why This Works:**
- ✅ We know exact cell dimensions (width÷columns, height÷rows)
- ✅ Can extract histogram from any image region via ImageMagick
- ✅ Residual background often clusters by color within cells
- ✅ Dominant colors (15%+ of pixels) likely background, not sprite details
- ✅ Faster than `--by-frame` (no video extraction/reassembly)
- ✅ More thorough than standard `--remove-bg` (per-cell color analysis)

### Functional Requirements

#### FR-7: Cell Cleanup Flag ❌ NOT STARTED

System SHALL add `--cleanup-cells` flag.

**Usage:**
```bash
ruby_spriter --video input.mp4 --remove-bg --cleanup-cells
ruby_spriter --batch --dir videos/ --remove-bg --cleanup-cells
```

**Validation:**
- Requires `--remove-bg` flag
- Requires `--video` or `--batch` mode
- Cannot use with `--by-frame` (redundant - by-frame already handles this)
- Error message: "ERROR: --cleanup-cells requires --remove-bg and cannot be used with --by-frame"

**CLI Acceptance Tests:**
```ruby
# Test: requires --remove-bg
expect { parse_args(['--video', 'input.mp4', '--cleanup-cells']) }
  .to raise_error(ValidationError, /requires --remove-bg/)

# Test: cannot use with --by-frame
expect { parse_args(['--video', 'input.mp4', '--remove-bg', '--by-frame', '--cleanup-cells']) }
  .to raise_error(ValidationError, /cannot be used with --by-frame/)

# Test: requires video or batch mode
expect { parse_args(['--image', 'sprite.png', '--remove-bg', '--cleanup-cells']) }
  .to raise_error(ValidationError, /requires --video or --batch/)
```

---

#### FR-8: Dominant Color Detection ❌ NOT STARTED

System SHALL detect dominant residual backgrounds per cell.

**Algorithm:**
```ruby
def analyze_cell_colors(cell_image_path)
  # 1. Extract histogram using ImageMagick
  cmd = "magick #{cell_image_path} -define histogram:unique-colors=true -format %c histogram:info:-"
  histogram_output = execute_command(cmd)
  
  # 2. Parse histogram into { color => pixel_count } hash
  colors = parse_histogram(histogram_output)
  
  # 3. Calculate total non-transparent pixels
  total_pixels = colors.values.sum
  return nil if total_pixels == 0  # Empty cell
  
  # 4. Find colors exceeding dominance threshold
  dominant_colors = colors.select do |color, count|
    percentage = (count.to_f / total_pixels) * 100
    percentage >= @config.cell_cleanup_threshold  # Default: 15.0%
  end
  
  # 5. Return dominant colors or nil
  dominant_colors.empty? ? nil : dominant_colors.keys
end

def parse_histogram(histogram_output)
  colors = {}
  histogram_output.each_line do |line|
    # Parse ImageMagick histogram format:
    # "1234: (255,0,0) #FF0000 srgb(255,0,0)"
    next unless line.match(/^\s*(\d+):\s*\((\d+),(\d+),(\d+)/)
    count = $1.to_i
    r, g, b = $2.to_i, $3.to_i, $4.to_i
    
    # Skip fully transparent pixels
    next if is_transparent?(line)
    
    colors["rgb(#{r},#{g},#{b})"] = count
  end
  colors
end
```

**Configuration:**
- `--cell-cleanup-threshold N` (default: 15.0, range: 1.0-50.0)
- Lower = more aggressive (may remove sprite details)
- Higher = more conservative (may miss residual background)

**Behavior:**
- Skip transparent pixels in histogram analysis
- Compare against total non-transparent pixels only
- Return multiple dominant colors if several exceed threshold
- Return `nil` if no dominant colors (cell is clean/all sprite)

**Unit Tests:**
```ruby
describe '#analyze_cell_colors' do
  it 'detects single dominant color above threshold' do
    # Cell with 80% red background, 20% sprite
    # Should return [rgb(255,0,0)]
  end
  
  it 'detects multiple dominant colors' do
    # Cell with 40% red, 35% blue background, 25% sprite
    # Should return [rgb(255,0,0), rgb(0,0,255)]
  end
  
  it 'returns nil when no dominant colors' do
    # Cell with many colors, none above 15%
    # Should return nil
  end
  
  it 'skips transparent pixels in calculation' do
    # Verify percentages calculated against non-transparent only
  end
end
```

---

#### FR-9: Cell-by-Cell Processing ❌ NOT STARTED

System SHALL process each cell independently using GIMP color selection.

**Workflow:**
```ruby
def cleanup_cells(spritesheet_path, options)
  cell_width = calculate_cell_width(options)
  cell_height = calculate_cell_height(options)
  rows = calculate_rows(options)
  columns = options[:columns]
  
  temp_dir = Utils::FileHelper.create_temp_dir('cell_cleanup')
  cleaned_cells = []
  stats = { processed: 0, cleaned: 0, skipped: 0, colors_removed: 0 }
  
  puts "\n🎨 Cell-Based Background Cleanup"
  puts "  Analyzing spritesheet: #{columns}x#{rows} grid (#{rows * columns} cells)"
  puts "  Dominance threshold: #{options[:cell_cleanup_threshold] || 15.0}%\n\n"
  
  (0...rows).each do |row|
    (0...columns).each do |col|
      cell_num = row * columns + col
      stats[:processed] += 1
      
      # Extract cell region
      cell_path = extract_cell(spritesheet_path, row, col, cell_width, cell_height, temp_dir)
      
      # Analyze for dominant colors
      dominant_colors = analyze_cell_colors(cell_path)
      
      if dominant_colors
        # Generate and execute GIMP script to remove dominant colors
        cleaned_cell = remove_dominant_colors(cell_path, dominant_colors, options, temp_dir)
        cleaned_cells << cleaned_cell
        stats[:cleaned] += 1
        stats[:colors_removed] += dominant_colors.length
        
        puts "  Cell [#{row},#{col}]: Removed #{dominant_colors.length} dominant color(s)"
      else
        # No cleanup needed
        cleaned_cells << cell_path
        stats[:skipped] += 1
        puts "  Cell [#{row},#{col}]: No dominant colors detected (skipped)"
      end
    end
  end
  
  # Reassemble cleaned cells
  reassemble_spritesheet(cleaned_cells, columns, rows, spritesheet_path)
  
  puts "\n  ✓ Cleanup complete"
  puts "  - Processed: #{stats[:processed]} cells"
  puts "  - Cleaned: #{stats[:cleaned]} cells"
  puts "  - Skipped: #{stats[:skipped]} cells"
  puts "  - Dominant colors removed: #{stats[:colors_removed]} total\n"
  
  stats
ensure
  Utils::FileHelper.cleanup_temp_dir(temp_dir) if temp_dir
end

def extract_cell(spritesheet_path, row, col, cell_width, cell_height, temp_dir)
  x_offset = col * cell_width
  y_offset = row * cell_height
  cell_path = File.join(temp_dir, "cell_#{row}_#{col}.png")
  
  # Use ImageMagick crop: magick spritesheet.png -crop WxH+X+Y +repage cell.png
  cmd = [
    'magick',
    Utils::PathHelper.quote_path(spritesheet_path),
    '-crop', "#{cell_width}x#{cell_height}+#{x_offset}+#{y_offset}",
    '+repage',
    Utils::PathHelper.quote_path(cell_path)
  ].join(' ')
  
  stdout, stderr, status = Open3.capture3(cmd)
  raise ProcessingError, "Failed to extract cell: #{stderr}" unless status.success?
  
  cell_path
end

def remove_dominant_colors(cell_path, dominant_colors, options, temp_dir)
  cleaned_path = cell_path.sub('.png', '_cleaned.png')
  
  # Generate GIMP Python-fu script
  script_path = File.join(temp_dir, "cleanup_#{File.basename(cell_path, '.png')}.py")
  script_content = CellCleanupGimpScript.generate_cleanup_script(
    cell_path,
    cleaned_path,
    dominant_colors
  )
  File.write(script_path, script_content)
  
  # Execute GIMP script
  gimp_processor = GimpProcessor.new(options[:gimp_path])
  gimp_processor.execute_python_script(script_path)
  
  Utils::FileHelper.validate_exists!(cleaned_path)
  cleaned_path
end

def reassemble_spritesheet(cell_paths, columns, rows, output_path)
  # Use ImageMagick montage to reassemble cells
  cmd = [
    'magick', 'montage',
    cell_paths.map { |p| Utils::PathHelper.quote_path(p) }.join(' '),
    '-tile', "#{columns}x#{rows}",
    '-geometry', '+0+0',  # No gaps/borders
    '-background', 'none',
    Utils::PathHelper.quote_path(output_path)
  ].join(' ')
  
  stdout, stderr, status = Open3.capture3(cmd)
  raise ProcessingError, "Failed to reassemble spritesheet: #{stderr}" unless status.success?
  
  Utils::FileHelper.validate_exists!(output_path)
end
```

**GIMP Color Selection:**
- Use `gimp-image-select-color()` with threshold=0 (exact color match)
- Use `CHANNEL_OP_ADD` to accumulate multiple dominant colors
- Clear selection to make transparent
- Export cleaned cell

**Unit Tests:**
```ruby
describe '#cleanup_cells' do
  it 'processes all cells in grid' do
    # Verify correct number of cells processed
  end
  
  it 'extracts cells with correct dimensions and offsets' do
    # Verify ImageMagick crop commands
  end
  
  it 'skips cells without dominant colors' do
    # Verify no GIMP processing for clean cells
  end
  
  it 'removes dominant colors from dirty cells' do
    # Verify GIMP script generation and execution
  end
  
  it 'reassembles cells maintaining original dimensions' do
    # Verify montage command and output size
  end
  
  it 'reports accurate statistics' do
    # Verify processed/cleaned/skipped counts
  end
end
```

---

#### FR-10: Progress Reporting ❌ NOT STARTED

System SHALL report cell cleanup progress and results.

**Console Output Format:**
```
🎨 Cell-Based Background Cleanup
  Analyzing spritesheet: 8x4 grid (32 cells)
  Dominance threshold: 15.0%

  Cell [0,0]: No dominant colors detected (skipped)
  Cell [0,1]: Removed 2 dominant color(s)
  Cell [0,2]: Removed 1 dominant color(s)
  Cell [0,3]: No dominant colors detected (skipped)
  ...
  Cell [3,7]: Removed 3 dominant color(s)

  ✓ Cleanup complete
  - Processed: 32 cells
  - Cleaned: 18 cells
  - Skipped: 14 cells
  - Dominant colors removed: 45 total
```

**PNG Metadata Embedding:**
```ruby
def embed_cell_cleanup_metadata(output_path, stats, options)
  metadata = {
    'cell_cleanup_applied' => 'true',
    'cell_cleanup_threshold' => options[:cell_cleanup_threshold] || 15.0,
    'cells_processed' => stats[:processed],
    'cells_cleaned' => stats[:cleaned],
    'cells_skipped' => stats[:skipped],
    'dominant_colors_removed' => stats[:colors_removed]
  }
  
  Utils::MetadataHelper.embed_metadata(output_path, metadata)
end
```

---

#### FR-11: Pipeline Integration ❌ NOT STARTED

System SHALL integrate cell cleanup into video and batch workflows.

**Video Mode Integration:**
```ruby
# In VideoProcessor#create_spritesheet
def create_spritesheet(video_path, output_path, options)
  # ... existing frame extraction and assembly ...
  
  # Standard background removal (if --remove-bg)
  if options[:remove_bg] && !options[:by_frame]
    apply_background_removal(output_path, options)
  end
  
  # Cell-based cleanup (if --cleanup-cells)
  if options[:cleanup_cells]
    cell_processor = CellCleanupProcessor.new(options)
    stats = cell_processor.cleanup_cells(output_path, options)
    
    # Embed metadata
    embed_cell_cleanup_metadata(output_path, stats, options)
  end
  
  # ... rest of processing (scaling, sharpening, etc.) ...
end
```

**Batch Mode Integration:**
```ruby
# In BatchProcessor#process_video
def process_video(video_file, options)
  # ... existing processing ...
  
  # Cell cleanup applies after standard background removal
  # (handled automatically by VideoProcessor integration above)
  
  # ... rest of processing ...
end
```

**Execution Order:**
1. Extract frames or assemble spritesheet
2. Apply standard background removal (`--remove-bg`) if not `--by-frame`
3. **Apply cell-based cleanup (`--cleanup-cells`)** ← NEW STEP
4. Apply scaling, sharpening, compression, etc.

**Integration Tests:**
```ruby
describe 'Cell cleanup integration' do
  context 'with video mode' do
    it 'applies cleanup after standard background removal' do
      # Verify execution order
    end
    
    it 'skips cleanup when --by-frame used' do
      # Verify validation prevents redundant processing
    end
  end
  
  context 'with batch mode' do
    it 'applies cleanup to all videos in batch' do
      # Verify batch processing includes cleanup
    end
  end
end
```

---

#### FR-12: Performance Target ❌ NOT STARTED

Cell cleanup SHALL add <30% to total processing time.

**Target Performance:**
- For 32-cell spritesheet: <10 seconds additional time
- Much faster than `--by-frame` (~120 sec for 32 frames)

**Optimizations:**

1. **Parallel Cell Processing:**
   ```ruby
   require 'concurrent'
   
   pool = Concurrent::FixedThreadPool.new(Concurrent.processor_count)
   futures = cells.map do |cell_info|
     Concurrent::Future.execute(executor: pool) do
       process_cell(cell_info)
     end
   end
   results = futures.map(&:value)
   pool.shutdown
   ```

2. **Skip Empty Cells:**
   ```ruby
   def skip_empty_cell?(cell_path)
     # Quick check: if >95% transparent, skip analysis
     cmd = "magick #{cell_path} -format '%[fx:mean]' info:"
     opacity = execute_command(cmd).to_f
     opacity < 0.05  # <5% opaque pixels
   end
   ```

3. **Cache Cell Extractions:**
   - Extract all cells once to temp directory
   - Process from temp files
   - Delete temp directory after reassembly

4. **Batch GIMP Operations:**
   - Combine multiple cell cleanups into single GIMP script where colors overlap
   - Reduces GIMP startup overhead

**Performance Tests:**
```ruby
describe 'Performance' do
  it 'adds <30% to total processing time' do
    # Benchmark with and without --cleanup-cells
    without_cleanup = benchmark { process_video_without_cleanup }
    with_cleanup = benchmark { process_video_with_cleanup }
    
    overhead = ((with_cleanup - without_cleanup) / without_cleanup) * 100
    expect(overhead).to be < 30
  end
  
  it 'is faster than --by-frame alternative' do
    cleanup_time = benchmark { process_with_cleanup_cells }
    by_frame_time = benchmark { process_with_by_frame }
    
    expect(cleanup_time).to be < (by_frame_time * 0.5)  # At least 2× faster
  end
end
```

### Technical Implementation

**New Classes:**

#### 1. CellCleanupProcessor (`lib/ruby_spriter/cell_cleanup_processor.rb`)

```ruby
module RubySpriter
  class CellCleanupProcessor
    def initialize(options = {})
      @config = CellCleanupConfig.new(options)
      @gimp_processor = GimpProcessor.new(options[:gimp_path])
    end
    
    def cleanup_cells(spritesheet_path, options)
      # Main entry point - full implementation above
    end
    
    private
    
    def calculate_cell_dimensions(options)
      # Extract from spritesheet dimensions and grid
      image_info = Utils::ImageHelper.get_dimensions(spritesheet_path)
      {
        width: image_info[:width] / options[:columns],
        height: image_info[:height] / calculate_rows(options)
      }
    end
    
    def calculate_rows(options)
      (options[:frames].to_f / options[:columns]).ceil
    end
    
    def extract_cell(spritesheet_path, row, col, cell_width, cell_height, temp_dir)
      # Implementation above
    end
    
    def analyze_cell_colors(cell_path)
      # Implementation above
    end
    
    def parse_histogram(histogram_output)
      # Implementation above
    end
    
    def remove_dominant_colors(cell_path, dominant_colors, options, temp_dir)
      # Implementation above
    end
    
    def reassemble_spritesheet(cell_paths, columns, rows, output_path)
      # Implementation above
    end
    
    def embed_cell_cleanup_metadata(output_path, stats, options)
      # Implementation above
    end
  end
end
```

#### 2. CellCleanupConfig (`lib/ruby_spriter/cell_cleanup_config.rb`)

```ruby
module RubySpriter
  class CellCleanupConfig
    attr_accessor :threshold, :parallel, :skip_empty
    
    def initialize(options = {})
      @threshold = options[:cell_cleanup_threshold] || 15.0
      @parallel = options.fetch(:cell_cleanup_parallel, true)
      @skip_empty = options.fetch(:cell_cleanup_skip_empty, true)
      
      validate!
    end
    
    private
    
    def validate!
      unless @threshold.between?(1.0, 50.0)
        raise ValidationError, "cell_cleanup_threshold must be between 1.0 and 50.0 (got: #{@threshold})"
      end
    end
  end
end
```

**Unit Tests:**
```ruby
describe CellCleanupConfig do
  describe '#initialize' do
    it 'uses default threshold of 15.0' do
      config = CellCleanupConfig.new
      expect(config.threshold).to eq(15.0)
    end
    
    it 'accepts custom threshold' do
      config = CellCleanupConfig.new(cell_cleanup_threshold: 20.0)
      expect(config.threshold).to eq(20.0)
    end
    
    it 'validates threshold range (1.0-50.0)' do
      expect { CellCleanupConfig.new(cell_cleanup_threshold: 0.5) }
        .to raise_error(ValidationError, /between 1.0 and 50.0/)
      
      expect { CellCleanupConfig.new(cell_cleanup_threshold: 55.0) }
        .to raise_error(ValidationError, /between 1.0 and 50.0/)
    end
  end
end
```

#### 3. CellCleanupGimpScript (`lib/ruby_spriter/cell_cleanup_gimp_script.rb`)

```ruby
module RubySpriter
  module CellCleanupGimpScript
    def self.generate_cleanup_script(input_path, output_path, dominant_colors)
      # Convert RGB strings to normalized values
      colors_py = dominant_colors.map do |color_str|
        # Parse "rgb(255,0,0)" format
        match = color_str.match(/rgb\((\d+),(\d+),(\d+)\)/)
        r, g, b = match[1].to_f / 255.0, match[2].to_f / 255.0, match[3].to_f / 255.0
        "[#{r}, #{g}, #{b}]"
      end.join(', ')
      
      <<~PYTHON
        import gi
        gi.require_version('Gimp', '3.0')
        from gi.repository import Gimp, Gio, Gegl
        import sys

        def cleanup_cell():
            try:
                # Load image
                img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,
                                    Gio.File.new_for_path(r'#{input_path}'))
                layer = img.get_layers()[0]
                
                if not layer.has_alpha():
                    layer.add_alpha()
                
                pdb = Gimp.get_pdb()
                
                # Dominant colors to remove (exact match, threshold=0)
                dominant_colors = [#{colors_py}]
                
                # Select each dominant color
                for i, (r, g, b) in enumerate(dominant_colors):
                    gegl_color = Gegl.Color.new('rgb(0,0,0)')
                    gegl_color.set_rgba(r, g, b, 1.0)
                    
                    select_proc = pdb.lookup_procedure('gimp-image-select-color')
                    config = select_proc.create_config()
                    config.set_property('image', img)
                    config.set_property('operation',
                        Gimp.ChannelOps.REPLACE if i == 0 else Gimp.ChannelOps.ADD)
                    config.set_property('drawable', layer)
                    config.set_property('color', gegl_color)
                    config.set_property('threshold', 0)  # Exact color match
                    select_proc.run(config)
                
                # Delete selection (make transparent)
                edit_clear = pdb.lookup_procedure('gimp-drawable-edit-clear')
                config = edit_clear.create_config()
                config.set_property('drawable', layer)
                edit_clear.run(config)
                
                # Deselect
                select_none = pdb.lookup_procedure('gimp-selection-none')
                config = select_none.create_config()
                config.set_property('image', img)
                select_none.run(config)
                
                # Export
                export_proc = pdb.lookup_procedure('file-png-export')
                config = export_proc.create_config()
                config.set_property('image', img)
                config.set_property('file', Gio.File.new_for_path(r'#{output_path}'))
                export_proc.run(config)
                
                print("SUCCESS - Cell cleanup complete!")
            except Exception as e:
                print(f"ERROR: {e}")
                sys.exit(1)

        sys.exit(cleanup_cell())
      PYTHON
    end
  end
end
```

**Unit Tests:**
```ruby
describe CellCleanupGimpScript do
  describe '.generate_cleanup_script' do
    it 'generates valid GIMP 3.x Python-fu script' do
      script = CellCleanupGimpScript.generate_cleanup_script(
        '/input.png',
        '/output.png',
        ['rgb(255,0,0)', 'rgb(0,255,0)']
      )
      
      expect(script).to include("gi.require_version('Gimp', '3.0')")
      expect(script).to include('gimp-image-select-color')
      expect(script).to include('[1.0, 0.0, 0.0]')  # Normalized red
      expect(script).to include('[0.0, 1.0, 0.0]')  # Normalized green
    end
    
    it 'uses exact color matching (threshold=0)' do
      script = CellCleanupGimpScript.generate_cleanup_script(
        '/input.png', '/output.png', ['rgb(255,0,0)']
      )
      
      expect(script).to include("'threshold', 0")
    end
    
    it 'uses ADD operation for multiple colors' do
      script = CellCleanupGimpScript.generate_cleanup_script(
        '/input.png', '/output.png', ['rgb(255,0,0)', 'rgb(0,255,0)']
      )
      
      expect(script).to include('Gimp.ChannelOps.REPLACE if i == 0 else Gimp.ChannelOps.ADD')
    end
  end
end
```

**Modified Classes:**

#### 1. CLI (`lib/ruby_spriter/cli.rb`)

Add new flags and validation:

```ruby
# In parse_options method
opts.on('--cleanup-cells', 'Apply cell-based background cleanup (requires --remove-bg, cannot use with --by-frame)') do
  options[:cleanup_cells] = true
end

opts.on('--cell-cleanup-threshold N', Float, 
        'Minimum percentage for dominant color detection (default: 15.0, range: 1.0-50.0)') do |n|
  options[:cell_cleanup_threshold] = n
end

# In validate_options method
def validate_cell_cleanup_options
  if options[:cleanup_cells]
    unless options[:remove_bg]
      raise ValidationError, "--cleanup-cells requires --remove-bg flag"
    end
    
    if options[:by_frame]
      raise ValidationError, "--cleanup-cells cannot be used with --by-frame (redundant)"
    end
    
    unless options[:video] || options[:batch]
      raise ValidationError, "--cleanup-cells requires --video or --batch mode"
    end
    
    if options[:cell_cleanup_threshold]
      unless options[:cell_cleanup_threshold].between?(1.0, 50.0)
        raise ValidationError, "--cell-cleanup-threshold must be between 1.0 and 50.0"
      end
    end
  end
end
```

**CLI Unit Tests:**
```ruby
describe 'CLI validation for --cleanup-cells' do
  it 'requires --remove-bg flag' do
    expect { parse_args(['--video', 'input.mp4', '--cleanup-cells']) }
      .to raise_error(ValidationError, /requires --remove-bg/)
  end
  
  it 'cannot be used with --by-frame' do
    expect { parse_args(['--video', 'input.mp4', '--remove-bg', '--by-frame', '--cleanup-cells']) }
      .to raise_error(ValidationError, /cannot be used with --by-frame/)
  end
  
  it 'requires video or batch mode' do
    expect { parse_args(['--image', 'sprite.png', '--remove-bg', '--cleanup-cells']) }
      .to raise_error(ValidationError, /requires --video or --batch/)
  end
  
  it 'validates threshold range' do
    expect { parse_args(['--video', 'input.mp4', '--remove-bg', '--cleanup-cells', '--cell-cleanup-threshold', '0.5']) }
      .to raise_error(ValidationError, /between 1.0 and 50.0/)
    
    expect { parse_args(['--video', 'input.mp4', '--remove-bg', '--cleanup-cells', '--cell-cleanup-threshold', '55.0']) }
      .to raise_error(ValidationError, /between 1.0 and 50.0/)
  end
  
  it 'accepts valid configuration' do
    args = parse_args(['--video', 'input.mp4', '--remove-bg', '--cleanup-cells', '--cell-cleanup-threshold', '20.0'])
    expect(args[:cleanup_cells]).to be true
    expect(args[:cell_cleanup_threshold]).to eq(20.0)
  end
end
```

#### 2. VideoProcessor (`lib/ruby_spriter/video_processor.rb`)

Integrate cell cleanup into pipeline:

```ruby
def create_spritesheet(video_path, output_path, options)
  # ... existing frame extraction/assembly ...
  
  # Standard background removal
  if options[:remove_bg] && !options[:by_frame]
    apply_background_removal(output_path, options)
  end
  
  # Cell-based cleanup (NEW)
  if options[:cleanup_cells]
    require_relative 'cell_cleanup_processor'
    cell_processor = CellCleanupProcessor.new(options)
    stats = cell_processor.cleanup_cells(output_path, options)
  end
  
  # ... rest of processing ...
end
```

**Integration Tests:**
```ruby
describe VideoProcessor do
  describe 'cell cleanup integration' do
    it 'applies cleanup after standard background removal' do
      processor = VideoProcessor.new
      expect(CellCleanupProcessor).to receive(:new).and_return(double(cleanup_cells: {}))
      
      processor.create_spritesheet('input.mp4', 'output.png', {
        remove_bg: true,
        cleanup_cells: true,
        columns: 4,
        frames: 16
      })
    end
    
    it 'skips cleanup when flag not present' do
      processor = VideoProcessor.new
      expect(CellCleanupProcessor).not_to receive(:new)
      
      processor.create_spritesheet('input.mp4', 'output.png', {
        remove_bg: true,
        columns: 4,
        frames: 16
      })
    end
  end
end
```

### Usage Examples

```bash
# Basic cell cleanup
ruby_spriter --video input.mp4 --remove-bg --cleanup-cells

# Custom threshold (more aggressive)
ruby_spriter --video input.mp4 --remove-bg --cleanup-cells --cell-cleanup-threshold 10.0

# Conservative cleanup
ruby_spriter --video input.mp4 --remove-bg --cleanup-cells --cell-cleanup-threshold 25.0

# Full pipeline with cleanup
ruby_spriter --video input.mp4 \
  --remove-bg \
  --cleanup-cells \
  --cell-cleanup-threshold 15.0 \
  --frames 64 --columns 8 \
  --scale 50 --sharpen \
  --max-compress

# Batch mode with cleanup
ruby_spriter --batch --dir videos/ --remove-bg --cleanup-cells

# Error: cannot use with --by-frame
ruby_spriter --video input.mp4 --remove-bg --by-frame --cleanup-cells
# ERROR: --cleanup-cells cannot be used with --by-frame (redundant)
```

### Performance Comparison

| Processing Mode | Time (32 frames) | Quality | Use Case |
|----------------|------------------|---------|----------|
| `--remove-bg` only | ~15 sec | Good | Uniform backgrounds |
| `--remove-bg --cleanup-cells` | ~25 sec | Very Good | Varying backgrounds, residual cleanup |
| `--remove-bg --by-frame` | ~120 sec | Excellent | Complex, highly varied backgrounds |

**Recommendation:** Use `--cleanup-cells` as default for videos with varying backgrounds. Reserve `--by-frame` for cases where cell cleanup proves insufficient.

### Acceptance Criteria

| # | Criterion | Status |
|---|-----------|--------|
| 32 | `--cleanup-cells` flag added and validated | ✅ |
| 33 | Requires `--remove-bg`, cannot use with `--by-frame` | ✅ |
| 34 | Detects dominant colors (>threshold %) per cell | ✅ |
| 35 | GIMP removes dominant colors from cells | ⚠️ Executes but ineffective |
| 36 | Skips cells without dominant colors | ✅ |
| 37 | Reassembled spritesheet maintains dimensions | ✅ |
| 38 | Progress reporting shows processed/cleaned/skipped | ✅ |
| 39 | PNG metadata includes cleanup statistics | ❌ Not implemented |
| 40 | Works with `--video` and `--batch` modes | ⚠️ Works but ineffective |
| 41 | Adds <30% to total processing time | ❌ Exceeds target |
| 42 | Faster than `--by-frame` alternative (>2×) | ❌ Not verified |
| 43 | Unit tests for CellCleanupProcessor | ✅ (13 tests) |
| 44 | Unit tests for CellCleanupConfig | ✅ (4 tests) |
| 45 | Unit tests for CellCleanupGimpScript | ✅ (4 tests) |
| 46 | CLI validation tests (6 tests) | ✅ |
| 47 | VideoProcessor integration tests | ✅ (2 tests) |
| 48 | Manual testing removes residual backgrounds | ❌ Ineffective |
| 49 | All existing tests continue to pass | ✅ (512/512) |

### Known Issues & Limitations

**Issue 1: Ineffective Background Removal (AC-35, AC-48)**
- **Severity:** High
- **Description:** While the feature executes successfully and processes all cells, it does not effectively remove residual background colors in practice. The GIMP color selection executes without errors but the selected regions are not being cleared properly.
- **Observed Behavior:**
  - Dominant colors are correctly detected (15/16 cells identified dominant colors in test)
  - GIMP script executes without errors
  - Output files are created
  - But visual inspection shows backgrounds remain in cells
- **Root Cause Analysis:**
  - GIMP 3.x `gimp-image-select-color` with no threshold parameter may use default threshold that doesn't match our intent
  - The exact color matching approach may not account for slight color variations
  - Possible GIMP context mode issues in batch mode
- **Recommendation:**
  - Investigate GIMP's default color selection threshold
  - Consider adding explicit threshold parameter if GIMP 3.x API supports it
  - Defer to v0.7.0.2 for refinement

**Issue 2: Performance Exceeds Target (AC-41)**
- **Severity:** Medium
- **Description:** Processing time significantly exceeds the <30% overhead target
- **Target:** Add <10 seconds for 16-cell spritesheet
- **Actual:** Not formally benchmarked but subjectively adds significant time per cell
- **Root Cause:**
  - Each cell invokes separate GIMP process (16 invocations for 16 cells)
  - No parallel processing implemented
  - ImageMagick crop/montage adds overhead
  - GIMP startup/shutdown per cell is expensive
- **Recommendation:**
  - Implement parallel cell processing (Concurrent::FixedThreadPool)
  - Batch multiple cells into single GIMP script if possible
  - Defer optimization to v0.7.0.2

**Issue 3: Missing PNG Metadata (AC-39)**
- **Severity:** Low
- **Description:** Cell cleanup statistics not embedded in PNG metadata
- **Impact:** Informational only - doesn't affect functionality
- **Status:** Deferred to v0.7.0.2

***

[Rest of document continues with existing content...]

## [START-DATA: Interactive Development Process Framework]

GitHub repo:  https://github.com/scooter-indie/ruby-spriter  
GitHub MCP Enabled as Plugin: Yes
GitHub Username: scooter-indie
GitHub Repo: scooter-indie/ruby-spriter
Target branch [version] [status]: rs_0701 [v0.7.0.1-dev] [in progress]  
Git status: gh and git installed  
Git Diff in KB: No
filesystem MCP Enabled as Plugin: Yes
Local access to target repository: Yes  
local repo location: E:\Projects\ruby-spriter
Web Scraping URLs in KB: Yes
Baseline version to build upon: v0.7.0 
Requirements in /requirements: Ruby Spriter v0.7.0.1 Requirements.md
Requirement in KB: No
Test Framework Location: /spec 
Necessary prerequisites installed: Yes  

**Implementation Status:**

- Core GIMP integration: ✅ Complete
- Processing order fixes: ✅ Complete
- Frame-by-frame processing: ✅ Complete
- BatchProcessor refactoring: ✅ Complete
- Cell-based cleanup: ❌ Not started (NEW FEATURE)
- Performance optimization: ✅ Complete (90% improvement)
- Timeout protection: ❌ Not implemented (deferred)
- Documentation updates: ❌ Pending

**Next Steps:**

1. ✅ ~~Complete regression testing~~ (Done)
2. ✅ ~~Performance optimization~~ (Complete - 90% faster)
3. ✅ ~~Frame-by-frame processing~~ (Complete)
4. ✅ ~~BatchProcessor refactoring~~ (Complete)
5. ❌ **Implement cell-based cleanup** (NEW - IN SCOPE)
6. ⚠️ Implement timeout protection (Deferred to v0.7.0.2)
7. ⚠️ Update documentation (Pending)
8. ⚠️ Update version to 0.7.0.1 (Pending)
9. ⚠️ Create pull request (Pending)

## [END-DATA: Interactive Development Process Framework]

***

## END OF REQUIREMENTS DOCUMENT
