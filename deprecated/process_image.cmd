@echo off
setlocal enabledelayedexpansion

REM Parse command line arguments - use %1 %2 %3 directly
set "inputfile=%~1"
set "scalepct=%~2"
set "operation=%~3"

REM If no input file argument, go to interactive mode
if not defined inputfile goto :prompt_input

REM Command line mode - set defaults
if not defined scalepct set "scalepct=50"
if not defined operation set "operation=3"

REM Add .png extension if not present - check last 4 characters
set "last4=%inputfile:~-4%"
if /i not "%last4%"==".png" set "inputfile=%inputfile%.png"

REM Check if file exists
if not exist "%inputfile%" (
    echo Error: File "%inputfile%" not found.
    exit /b 1
)

goto :process_image

:prompt_input
REM Interactive mode - prompt for inputs
echo.
echo Usage: %~nx0 [filename] [scale_percent] [operation]
echo.
echo   filename      - PNG file to process
echo   scale_percent - Scale percentage (default: 50)
echo   operation     - 1=Scale, 2=RemoveBG, 3=Scale+RemoveBG, 4=RemoveBG+Scale (default: 3)
echo.
echo Examples:
echo   %~nx0 image.png
echo   %~nx0 image.png 75
echo   %~nx0 image.png 50 2
echo   %~nx0 image.png 25 4
echo.

set /p "inputfile=Enter PNG filename (with or without .png extension): "

REM Check if input is empty
if not defined inputfile (
    echo Error: No filename entered.
    goto :prompt_input
)

REM Add .png extension if not present - check last 4 characters
set "last4=%inputfile:~-4%"
if /i not "%last4%"==".png" set "inputfile=%inputfile%.png"

REM Check if file exists
if not exist "%inputfile%" (
    echo Error: File "%inputfile%" not found.
    goto :prompt_input
)

REM Ask for scale percentage
set /p "scalepct=Enter scale percentage (default 50): "
if not defined scalepct set "scalepct=50"

REM Ask what operations to perform
echo.
echo Select operations:
echo 1 - Scale only
echo 2 - Remove background only
echo 3 - Scale and remove background
echo 4 - Remove background and scale
set /p "operation=Enter choice (1-4, default 3): "
if not defined operation set "operation=3"

:process_image
REM Validate scale percentage is a number
echo %scalepct%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo Error: Scale percentage must be a number
    exit /b 1
)

REM Validate operation is 1-4
if not "%operation%"=="1" if not "%operation%"=="2" if not "%operation%"=="3" if not "%operation%"=="4" (
    echo Error: Operation must be 1, 2, 3, or 4
    exit /b 1
)

REM Get the full path of input file
for %%F in ("%inputfile%") do (
    set "basename=%%~nF"
    set "filepath=%%~dpF"
    set "fullpath=%%~fF"
)

REM Create output filename with full path
set "suffix="
if "%operation%"=="1" set "suffix=-scaled"
if "%operation%"=="2" set "suffix=-nobg"
if "%operation%"=="3" set "suffix=-scaled-nobg"
if "%operation%"=="4" set "suffix=-nobg-scaled"

for %%F in ("%filepath%%basename%%suffix%.png") do set "outputfile=%%~fF"

echo.
echo ========================================
echo        GIMP IMAGE PROCESSING
echo ========================================
echo Input:     %fullpath%
echo Output:    %outputfile%
echo Scale:     %scalepct%%%
if "%operation%"=="1" echo Operation: Scale only
if "%operation%"=="2" echo Operation: Remove background only
if "%operation%"=="3" echo Operation: Scale and remove background
if "%operation%"=="4" echo Operation: Remove background and scale
echo ========================================
echo.

REM Create temporary Python script
set "tempscript=%TEMP%\gimp_process_%RANDOM%.py"
set "outputlog=%TEMP%\gimp_process_%RANDOM%.txt"

echo import sys > "%tempscript%"
echo sys.stdout = open(r'%outputlog%', 'w', buffering=1) >> "%tempscript%"
echo sys.stderr = sys.stdout >> "%tempscript%"
echo. >> "%tempscript%"
echo from gi.repository import Gimp, Gio >> "%tempscript%"
echo. >> "%tempscript%"
echo input_file = r"""%fullpath%""" >> "%tempscript%"
echo output_file = r"""%outputfile%""" >> "%tempscript%"
echo scale_percent = %scalepct% / 100.0 >> "%tempscript%"
echo operation = %operation% >> "%tempscript%"
echo. >> "%tempscript%"
echo print("="*50) >> "%tempscript%"
echo print("GIMP Image Processing Script") >> "%tempscript%"
echo print("="*50) >> "%tempscript%"
echo print("Input:", input_file) >> "%tempscript%"
echo print("Output:", output_file) >> "%tempscript%"
echo print("Scale:", int(scale_percent * 100), "%%") >> "%tempscript%"
echo print("Operation:", operation) >> "%tempscript%"
echo print("="*50) >> "%tempscript%"
echo print() >> "%tempscript%"
echo. >> "%tempscript%"
echo def remove_background(img, layer, pdb): >> "%tempscript%"
echo     """Remove background by sampling all four corners""" >> "%tempscript%"
echo     print("--- BACKGROUND REMOVAL ---") >> "%tempscript%"
echo     w = img.get_width() >> "%tempscript%"
echo     h = img.get_height() >> "%tempscript%"
echo. >> "%tempscript%"
echo     if not layer.has_alpha(): >> "%tempscript%"
echo         layer.add_alpha() >> "%tempscript%"
echo         print("  Added alpha channel") >> "%tempscript%"
echo     else: >> "%tempscript%"
echo         print("  Layer already has alpha channel") >> "%tempscript%"
echo. >> "%tempscript%"
echo     # Sample from all four corners >> "%tempscript%"
echo     corners = [(0, 0), (w-1, 0), (0, h-1), (w-1, h-1)] >> "%tempscript%"
echo     print("  Sampling {} corners for background color...".format(len(corners))) >> "%tempscript%"
echo. >> "%tempscript%"
echo     select_proc = pdb.lookup_procedure('gimp-image-select-color') >> "%tempscript%"
echo     if not select_proc: >> "%tempscript%"
echo         print("  ERROR: Could not find select-color procedure") >> "%tempscript%"
echo         return False >> "%tempscript%"
echo. >> "%tempscript%"
echo     for i, (x, y) in enumerate(corners): >> "%tempscript%"
echo         color = layer.get_pixel(x, y) >> "%tempscript%"
echo         print("  Corner {}: ({}, {})".format(i+1, x, y)) >> "%tempscript%"
echo. >> "%tempscript%"
echo         config = select_proc.create_config() >> "%tempscript%"
echo         config.set_property('image', img) >> "%tempscript%"
echo         config.set_property('operation', Gimp.ChannelOps.REPLACE if i == 0 else Gimp.ChannelOps.ADD) >> "%tempscript%"
echo         config.set_property('drawable', layer) >> "%tempscript%"
echo         config.set_property('color', color) >> "%tempscript%"
echo         select_proc.run(config) >> "%tempscript%"
echo. >> "%tempscript%"
echo     print("  Background selected from all corners") >> "%tempscript%"
echo. >> "%tempscript%"
echo     # Grow selection by 1 pixel to catch edge pixels >> "%tempscript%"
echo     grow_proc = pdb.lookup_procedure('gimp-selection-grow') >> "%tempscript%"
echo     if grow_proc: >> "%tempscript%"
echo         config = grow_proc.create_config() >> "%tempscript%"
echo         config.set_property('image', img) >> "%tempscript%"
echo         config.set_property('steps', 1) >> "%tempscript%"
echo         grow_proc.run(config) >> "%tempscript%"
echo         print("  Selection grown by 1 pixel") >> "%tempscript%"
echo. >> "%tempscript%"
echo     # Clear the selection >> "%tempscript%"
echo     edit_clear = pdb.lookup_procedure('gimp-drawable-edit-clear') >> "%tempscript%"
echo     if edit_clear: >> "%tempscript%"
echo         config = edit_clear.create_config() >> "%tempscript%"
echo         config.set_property('drawable', layer) >> "%tempscript%"
echo         edit_clear.run(config) >> "%tempscript%"
echo         print("  Background removed successfully") >> "%tempscript%"
echo     else: >> "%tempscript%"
echo         print("  ERROR: Could not find clear procedure") >> "%tempscript%"
echo         return False >> "%tempscript%"
echo. >> "%tempscript%"
echo     # Deselect >> "%tempscript%"
echo     select_none = pdb.lookup_procedure('gimp-selection-none') >> "%tempscript%"
echo     if select_none: >> "%tempscript%"
echo         config = select_none.create_config() >> "%tempscript%"
echo         config.set_property('image', img) >> "%tempscript%"
echo         select_none.run(config) >> "%tempscript%"
echo         print("  Selection cleared") >> "%tempscript%"
echo. >> "%tempscript%"
echo     return True >> "%tempscript%"
echo. >> "%tempscript%"
echo def scale_image(img, scale_percent): >> "%tempscript%"
echo     """Scale image by percentage""" >> "%tempscript%"
echo     print("--- IMAGE SCALING ---") >> "%tempscript%"
echo     w = img.get_width() >> "%tempscript%"
echo     h = img.get_height() >> "%tempscript%"
echo     new_w = int(w * scale_percent) >> "%tempscript%"
echo     new_h = int(h * scale_percent) >> "%tempscript%"
echo. >> "%tempscript%"
echo     print("  Original size: {}x{}".format(w, h)) >> "%tempscript%"
echo     print("  New size: {}x{}".format(new_w, new_h)) >> "%tempscript%"
echo     print("  Scaling...") >> "%tempscript%"
echo. >> "%tempscript%"
echo     img.scale(new_w, new_h) >> "%tempscript%"
echo     print("  Image scaled successfully") >> "%tempscript%"
echo     return True >> "%tempscript%"
echo. >> "%tempscript%"
echo try: >> "%tempscript%"
echo     print("STEP 1: Loading image...") >> "%tempscript%"
echo     img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE, Gio.File.new_for_path(input_file)) >> "%tempscript%"
echo     print("  Image loaded: {}x{}".format(img.get_width(), img.get_height())) >> "%tempscript%"
echo     print() >> "%tempscript%"
echo. >> "%tempscript%"
echo     layers = img.get_layers() >> "%tempscript%"
echo     if len(layers) == 0: >> "%tempscript%"
echo         raise Exception("No layers found in image") >> "%tempscript%"
echo     layer = layers[0] >> "%tempscript%"
echo. >> "%tempscript%"
echo     pdb = Gimp.get_pdb() >> "%tempscript%"
echo. >> "%tempscript%"
echo     # Perform operations based on choice >> "%tempscript%"
echo     if operation == 1: >> "%tempscript%"
echo         print("STEP 2: Scaling image...") >> "%tempscript%"
echo         scale_image(img, scale_percent) >> "%tempscript%"
echo     elif operation == 2: >> "%tempscript%"
echo         print("STEP 2: Removing background...") >> "%tempscript%"
echo         remove_background(img, layer, pdb) >> "%tempscript%"
echo     elif operation == 3: >> "%tempscript%"
echo         print("STEP 2: Scaling image...") >> "%tempscript%"
echo         scale_image(img, scale_percent) >> "%tempscript%"
echo         print() >> "%tempscript%"
echo         print("STEP 3: Removing background...") >> "%tempscript%"
echo         # Need to get layer again after scaling >> "%tempscript%"
echo         layers = img.get_layers() >> "%tempscript%"
echo         layer = layers[0] >> "%tempscript%"
echo         remove_background(img, layer, pdb) >> "%tempscript%"
echo     elif operation == 4: >> "%tempscript%"
echo         print("STEP 2: Removing background...") >> "%tempscript%"
echo         remove_background(img, layer, pdb) >> "%tempscript%"
echo         print() >> "%tempscript%"
echo         print("STEP 3: Scaling image...") >> "%tempscript%"
echo         scale_image(img, scale_percent) >> "%tempscript%"
echo. >> "%tempscript%"
echo     print() >> "%tempscript%"
echo     print("--- SAVING IMAGE ---") >> "%tempscript%"
echo     export_proc = pdb.lookup_procedure('file-png-export') >> "%tempscript%"
echo     if export_proc: >> "%tempscript%"
echo         config = export_proc.create_config() >> "%tempscript%"
echo         config.set_property('image', img) >> "%tempscript%"
echo         config.set_property('file', Gio.File.new_for_path(output_file)) >> "%tempscript%"
echo         export_proc.run(config) >> "%tempscript%"
echo         print("  Image saved successfully!") >> "%tempscript%"
echo         print() >> "%tempscript%"
echo         print("="*50) >> "%tempscript%"
echo         print("SUCCESS!") >> "%tempscript%"
echo         print("="*50) >> "%tempscript%"
echo     else: >> "%tempscript%"
echo         print("  ERROR: Could not find PNG export procedure") >> "%tempscript%"
echo. >> "%tempscript%"
echo except Exception as e: >> "%tempscript%"
echo     print() >> "%tempscript%"
echo     print("="*50) >> "%tempscript%"
echo     print("ERROR:", str(e)) >> "%tempscript%"
echo     print("="*50) >> "%tempscript%"
echo     import traceback >> "%tempscript%"
echo     traceback.print_exc() >> "%tempscript%"
echo finally: >> "%tempscript%"
echo     try: >> "%tempscript%"
echo         img.delete() >> "%tempscript%"
echo     except: >> "%tempscript%"
echo         pass >> "%tempscript%"
echo     sys.stdout.close() >> "%tempscript%"

REM Run GIMP with the Python script
"C:\Program Files\GIMP 3\bin\gimp-console-3.0.exe" --quit --batch-interpreter=python-fu-eval -b "exec(open(r'%tempscript%').read())"

set GIMP_ERROR=%errorlevel%

echo.
echo ========================================
echo             DEBUG OUTPUT
echo ========================================
if exist "%outputlog%" (
    type "%outputlog%"
) else (
    echo No output log created
)
echo ========================================
echo.

REM Check if output file was actually created
if exist "%outputfile%" (
    echo.
    echo *** SUCCESS! ***
    echo.
    echo Output saved as:
    echo %outputfile%
    echo.
    del "%tempscript%" 2>nul
    del "%outputlog%" 2>nul
    exit /b 0
) else (
    echo.
    echo *** ERROR: Output file was not created! ***
    echo.
    echo Debug files kept:
    echo   Script: %tempscript%
    if exist "%outputlog%" (
        echo   Log: %outputlog%
    )
    echo.
    exit /b 1
)
