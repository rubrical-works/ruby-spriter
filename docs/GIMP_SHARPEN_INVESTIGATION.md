# GIMP Sharpen Investigation

## Problem Statement

During development of Ruby Spriter v0.6.2, we attempted to implement image sharpening using GIMP's unsharp mask capabilities through GIMP 3.x batch mode (Python-fu). Despite extensive investigation and multiple implementation attempts, GIMP's GEGL operations proved unreliable in batch mode.

## Context

- **Goal**: Apply unsharp mask sharpening to images after scaling
- **Environment**: GIMP 3.x with Python-fu batch scripting
- **Use Case**: Restore edge definition in images that have been downscaled (e.g., 50% reduction)
- **Desired Parameters**: Radius, amount/gain, threshold

## Attempts Made

### Attempt 1: plug-in-unsharp-mask

**Code:**
```python
pdb = Gimp.get_pdb()
unsharp_proc = pdb.lookup_procedure('plug-in-unsharp-mask')
if unsharp_proc:
    config = unsharp_proc.create_config()
    config.set_property('drawable', layer)
    config.set_property('radius', radius)
    config.set_property('amount', amount)
    config.set_property('threshold', threshold)
    unsharp_proc.run(config)
```

**Result:** ❌ Failed
- **Error**: Procedure `plug-in-unsharp-mask` not found
- **Reason**: Legacy GIMP 2.x procedure name, not available in GIMP 3.x

### Attempt 2: filters-unsharp-mask

**Code:**
```python
unsharp_proc = pdb.lookup_procedure('filters-unsharp-mask')
```

**Result:** ❌ Failed
- **Error**: Procedure not found
- **Reason**: Incorrect procedure naming for GIMP 3.x

### Attempt 3: gegl:unsharp-mask

**Code:**
```python
unsharp_proc = pdb.lookup_procedure('gegl:unsharp-mask')
```

**Result:** ❌ Failed
- **Error**: Invalid procedure identifier
- **Reason**: Colon notation (`gegl:operation-name`) not valid for PDB lookups

### Attempt 4: gimp-drawable-apply-operation

**Code:**
```python
apply_op = pdb.lookup_procedure('gimp-drawable-apply-operation')
if apply_op:
    config = apply_op.create_config()
    config.set_property('drawable', layer)
    config.set_property('operation', 'gegl:unsharp-mask')
    config.set_property('options', f'radius={radius} scale={amount}')
    apply_op.run(config)
```

**Result:** ❌ Failed
- **Error**: Procedure `gimp-drawable-apply-operation` does not exist
- **Reason**: Not a valid PDB procedure in GIMP 3.x

### Attempt 5: Gimp.gegl_apply_operation

**Code:**
```python
from gi.repository import Gimp, Gegl

Gimp.gegl_apply_operation(
    layer,
    'gegl:unsharp-mask',
    {'radius': radius, 'scale': amount, 'threshold': threshold}
)
```

**Result:** ❌ Failed
- **Error**: `AttributeError: module 'gi.repository.Gimp' has no attribute 'gegl_apply_operation'`
- **Reason**: Method doesn't exist in GIMP 3.x Python bindings

### Attempt 6: GEGL Graph with Processor

**Code:**
```python
from gi.repository import Gegl

# Initialize GEGL
Gegl.init(None)

# Create graph
graph = Gegl.Node()
input_node = graph.create_child('gegl:buffer-source')
unsharp_node = graph.create_child('gegl:unsharp-mask')
output_node = graph.create_child('gegl:buffer-sink')

# Set properties
unsharp_node.set_property('radius', radius)
unsharp_node.set_property('scale', amount)

# Connect nodes
input_node.link(unsharp_node)
unsharp_node.link(output_node)

# Process
processor = Gegl.Processor.new_for_node(output_node)
while processor.work():
    pass
```

**Result:** ❌ Failed
- **Error**: `AttributeError: type object 'Processor' has no attribute 'new_for_node'`
- **Reason**: GEGL Processor API not properly exposed in Python bindings

### Attempt 7: GEGL Buffer Processing

**Code:**
```python
from gi.repository import Gegl, Babl

# Get layer buffer
layer_buffer = layer.get_buffer()

# Create output buffer
output_buffer = Gegl.Buffer.new(
    layer_buffer.get_extent(),
    Babl.format('R\'G\'B\'A float')
)

# Apply operation
layer_buffer.blit(
    layer_buffer.get_extent(),
    'gegl:unsharp-mask',
    output_buffer,
    None,
    Gegl.BlitFlags.DEFAULT
)

# Set processed buffer back
layer.set_buffer(output_buffer)
```

**Result:** ❌ Failed
- **Error**: `TypeError: Gegl.Buffer.blit() takes exactly 5 arguments (6 given)`
- **Reason**: Incorrect blit() method signature, doesn't support GEGL operation as parameter

### Attempt 8: Shadow Buffer Approach

**Code:**
```python
from gi.repository import Gegl, Babl

# Get shadow buffer (writeable copy)
shadow = layer.get_buffer()

# Create GEGL graph
graph = Gegl.Node()
input_node = graph.create_child('gegl:buffer-source')
input_node.set_property('buffer', shadow)

unsharp_node = graph.create_child('gegl:unsharp-mask')
unsharp_node.set_property('std-dev', radius)
unsharp_node.set_property('scale', amount)

output_node = graph.create_child('gegl:buffer-sink')

# Connect and process
input_node.connect_to('output', unsharp_node, 'input')
unsharp_node.connect_to('output', output_node, 'input')

output_node.process()
result_buffer = output_node.get_property('buffer')

# Apply back to layer
layer.set_buffer(result_buffer)
layer.merge_shadow(True)
```

**Result:** ❌ Failed
- **Error**: GEGL-CRITICAL warnings about hash table initialization
- **Debug Output**:
  ```
  GEGL-CRITICAL **: 16:20:31.057: gegl_operation_get_key:
  assertion 'operation_class->hash_table_init != NULL' failed
  ```
- **Reason**: GEGL operations in batch mode have critical hash table initialization issues

## Root Cause Analysis

### Why GIMP GEGL Failed in Batch Mode

1. **Incomplete Python Bindings**: Many GEGL operations that work in interactive GIMP don't have proper Python API exposure in batch mode

2. **Hash Table Initialization Issues**: GEGL operations require proper initialization that doesn't occur correctly in batch/non-interactive mode:
   ```
   GEGL-CRITICAL: gegl_operation_get_key: assertion 'operation_class->hash_table_init != NULL' failed
   ```

3. **PDB Procedure Limitations**: The traditional PDB (Procedural Database) procedures for filters like `plug-in-unsharp-mask` are legacy GIMP 2.x procedures not fully ported to GIMP 3.x GEGL architecture

4. **Buffer API Complexity**: Direct buffer manipulation through GEGL requires complex setup and proper context initialization that's difficult to achieve in Python-fu scripts

5. **Batch Mode vs Interactive Mode**: GEGL operations are optimized for interactive use within the GIMP UI, not for batch processing scenarios

## Solution: ImageMagick

After exhausting GIMP options, we implemented sharpening using **ImageMagick's unsharp mask**, which proved reliable and consistent:

### Implementation

**Location:** `lib/ruby_spriter/gimp_processor.rb:619-665`

```ruby
def apply_sharpen_imagemagick(input_file)
  radius = options[:sharpen_radius] || 2.0
  gain = options[:sharpen_gain] || 0.5
  threshold = options[:sharpen_threshold] || 0.03

  output_file = Utils::FileHelper.output_filename(input_file, "sharpened")

  magick_cmd = Platform.imagemagick_convert_cmd

  # ImageMagick unsharp format: {radius}x{sigma}+{gain}+{threshold}
  sigma = radius * 0.5
  unsharp_params = "#{radius}x#{sigma}+#{gain}+#{threshold}"

  cmd = [
    magick_cmd,
    Utils::PathHelper.quote_path(input_file),
    '-unsharp', unsharp_params,
    Utils::PathHelper.quote_path(output_file)
  ].join(' ')

  stdout, stderr, status = Open3.capture3(cmd)

  unless status.success?
    raise ProcessingError, "ImageMagick sharpen failed: #{stderr}"
  end

  Utils::FileHelper.validate_exists!(output_file)
  preserve_metadata(input_file, output_file)

  output_file
end
```

### Why ImageMagick Works

1. **Stable CLI Interface**: ImageMagick provides a stable, well-documented command-line interface
2. **Consistent Behavior**: Works identically across Windows, Linux, and macOS
3. **Simple Integration**: Easy to call via shell commands with predictable results
4. **Proper Parameter Support**: Direct support for radius, sigma, gain, and threshold
5. **No Batch Mode Issues**: Designed for scripting and automation

### Pipeline Placement

Sharpening is applied **after** all GIMP operations to avoid interference:

**Location:** `lib/ruby_spriter/gimp_processor.rb:38-41`

```ruby
# Apply sharpening at the very end, after all GIMP operations
if options[:sharpen]
  working_file = apply_sharpen_imagemagick(working_file)
end
```

## Default Parameter Tuning

Through testing, we determined optimal defaults to avoid halo artifacts:

```ruby
sharpen_radius: 2.0      # Effect size in pixels
sharpen_gain: 0.5        # Sharpening intensity (0.0-2.0+)
sharpen_threshold: 0.03  # Minimum change threshold (0.0-1.0)
```

### Halo Artifact Issues

**Initial defaults caused halos:**
- radius: 3.0, gain: 1.0, threshold: 0.0
- **Problem**: Over-sharpening of subtle gradients created artificial halos

**Solution:**
- Reduced radius to 2.0 (smaller effect area)
- Reduced gain to 0.5 (less aggressive)
- Increased threshold to 0.03 (only sharpen significant edges)

## Lessons Learned

1. **GIMP 3.x Batch Mode Limitations**: GEGL operations are not reliable in Python-fu batch scripts
2. **Use Right Tool for Job**: ImageMagick is purpose-built for batch image processing
3. **Pipeline Order Matters**: Apply sharpening last to avoid interfering with other operations
4. **Platform Consistency**: Cross-platform tools (ImageMagick) provide more predictable behavior
5. **Conservative Defaults**: Start with subtle effects and allow users to increase intensity

## References

- **ImageMagick Unsharp Documentation**: https://imagemagick.org/script/command-line-options.php#unsharp
- **GIMP 3.x Python-fu API**: https://www.gimp.org/docs/python/
- **GEGL Operations**: https://www.gegl.org/operations/

## Conclusion

While GIMP 3.x offers powerful image processing capabilities through GEGL, its batch mode implementation has significant limitations that make it unsuitable for automated sharpening operations. ImageMagick provides a reliable, cross-platform alternative that integrates seamlessly into the Ruby Spriter processing pipeline.

The failed attempts documented here serve as a reference for future development and demonstrate why external tools like ImageMagick remain valuable even when more sophisticated options like GIMP are available.

---

**Document Version**: 1.0
**Date**: 2025-10-22
**Ruby Spriter Version**: 0.6.2
**Author**: Claude Code with scooter-indie
