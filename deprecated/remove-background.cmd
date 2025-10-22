@echo off
setlocal enabledelayedexpansion

:input
set /p "inputfile=Enter PNG filename (with or without .png extension): "

REM Check if input is empty
if "%inputfile%"=="" (
    echo Error: No filename entered.
    goto input
)

REM Add .png extension if not present
echo %inputfile% | findstr /i "\.png$" >nul
if errorlevel 1 (
    set "inputfile=%inputfile%.png"
)

REM Check if file exists
if not exist "%inputfile%" (
    echo Error: File "%inputfile%" not found.
    goto input
)

REM Get the full path of input file
for %%F in ("%inputfile%") do (
    set "basename=%%~nF"
    set "filepath=%%~dpF"
    set "fullpath=%%~fF"
)

REM Create output filename with full path
for %%F in ("%filepath%%basename%-nobg.png") do set "outputfile=%%~fF"

echo.
echo Input:  %fullpath%
echo Output: %outputfile%
echo.
echo Removing background to transparency...
echo.

REM Create temporary Python script
set "tempscript=%TEMP%\gimp_removebg.py"
set "outputlog=%TEMP%\gimp_removebg.txt"

echo import sys > "%tempscript%"
echo sys.stdout = open(r'%outputlog%', 'w', buffering=1) >> "%tempscript%"
echo sys.stderr = sys.stdout >> "%tempscript%"
echo. >> "%tempscript%"
echo from gi.repository import Gimp, Gio >> "%tempscript%"
echo. >> "%tempscript%"
echo input_file = r"""%fullpath%""" >> "%tempscript%"
echo output_file = r"""%outputfile%""" >> "%tempscript%"
echo. >> "%tempscript%"
echo try: >> "%tempscript%"
echo     print("Loading image...") >> "%tempscript%"
echo     img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE, Gio.File.new_for_path(input_file)) >> "%tempscript%"
echo     w = img.get_width() >> "%tempscript%"
echo     h = img.get_height() >> "%tempscript%"
echo     print("Image loaded:", w, "x", h) >> "%tempscript%"
echo. >> "%tempscript%"
echo     layers = img.get_layers() >> "%tempscript%"
echo     layer = layers[0] >> "%tempscript%"
echo. >> "%tempscript%"
echo     if not layer.has_alpha(): >> "%tempscript%"
echo         layer.add_alpha() >> "%tempscript%"
echo         print("Added alpha channel") >> "%tempscript%"
echo. >> "%tempscript%"
echo     pdb = Gimp.get_pdb() >> "%tempscript%"
echo. >> "%tempscript%"
echo     # Sample from all four corners and select background >> "%tempscript%"
echo     corners = [ >> "%tempscript%"
echo         (0, 0),           # Top-left >> "%tempscript%"
echo         (w-1, 0),         # Top-right >> "%tempscript%"
echo         (0, h-1),         # Bottom-left >> "%tempscript%"
echo         (w-1, h-1)        # Bottom-right >> "%tempscript%"
echo     ] >> "%tempscript%"
echo. >> "%tempscript%"
echo     select_proc = pdb.lookup_procedure('gimp-image-select-color') >> "%tempscript%"
echo. >> "%tempscript%"
echo     for i, (x, y) in enumerate(corners): >> "%tempscript%"
echo         print("Sampling corner", i+1, "at ({}, {})...".format(x, y)) >> "%tempscript%"
echo         color = layer.get_pixel(x, y) >> "%tempscript%"
echo. >> "%tempscript%"
echo         if select_proc: >> "%tempscript%"
echo             config = select_proc.create_config() >> "%tempscript%"
echo             config.set_property('image', img) >> "%tempscript%"
echo             # Use ADD operation after first selection to combine >> "%tempscript%"
echo             if i == 0: >> "%tempscript%"
echo                 config.set_property('operation', Gimp.ChannelOps.REPLACE) >> "%tempscript%"
echo             else: >> "%tempscript%"
echo                 config.set_property('operation', Gimp.ChannelOps.ADD) >> "%tempscript%"
echo             config.set_property('drawable', layer) >> "%tempscript%"
echo             config.set_property('color', color) >> "%tempscript%"
echo             select_proc.run(config) >> "%tempscript%"
echo. >> "%tempscript%"
echo     print("Background selected from all corners") >> "%tempscript%"
echo. >> "%tempscript%"
echo     # Optional: Grow selection slightly to catch edge pixels >> "%tempscript%"
echo     grow_proc = pdb.lookup_procedure('gimp-selection-grow') >> "%tempscript%"
echo     if grow_proc: >> "%tempscript%"
echo         config = grow_proc.create_config() >> "%tempscript%"
echo         config.set_property('image', img) >> "%tempscript%"
echo         config.set_property('steps', 1)  # Grow by 1 pixel >> "%tempscript%"
echo         grow_proc.run(config) >> "%tempscript%"
echo         print("Selection grown by 1 pixel") >> "%tempscript%"
echo. >> "%tempscript%"
echo     print("Removing background...") >> "%tempscript%"
echo     edit_clear = pdb.lookup_procedure('gimp-drawable-edit-clear') >> "%tempscript%"
echo     if edit_clear: >> "%tempscript%"
echo         config2 = edit_clear.create_config() >> "%tempscript%"
echo         config2.set_property('drawable', layer) >> "%tempscript%"
echo         edit_clear.run(config2) >> "%tempscript%"
echo         print("Background removed") >> "%tempscript%"
echo. >> "%tempscript%"
echo     print("Deselecting...") >> "%tempscript%"
echo     select_none = pdb.lookup_procedure('gimp-selection-none') >> "%tempscript%"
echo     if select_none: >> "%tempscript%"
echo         config3 = select_none.create_config() >> "%tempscript%"
echo         config3.set_property('image', img) >> "%tempscript%"
echo         select_none.run(config3) >> "%tempscript%"
echo. >> "%tempscript%"
echo     print("Saving image...") >> "%tempscript%"
echo     export_proc = pdb.lookup_procedure('file-png-export') >> "%tempscript%"
echo     if export_proc: >> "%tempscript%"
echo         config = export_proc.create_config() >> "%tempscript%"
echo         config.set_property('image', img) >> "%tempscript%"
echo         config.set_property('file', Gio.File.new_for_path(output_file)) >> "%tempscript%"
echo         export_proc.run(config) >> "%tempscript%"
echo         print("SUCCESS - Image saved!") >> "%tempscript%"
echo. >> "%tempscript%"
echo except Exception as e: >> "%tempscript%"
echo     print("ERROR:", str(e)) >> "%tempscript%"
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

echo === Debug Output ===
if exist "%outputlog%" (
    type "%outputlog%"
    echo.
) else (
    echo No output log created
)
echo ====================
echo.

REM Check if output file was actually created
if exist "%outputfile%" (
    echo.
    echo SUCCESS! Background removed and saved as:
    echo %outputfile%
    del "%tempscript%" 2>nul
    del "%outputlog%" 2>nul
) else (
    echo.
    echo ERROR: Output file was not created!
    echo.
    echo Debug files:
    echo Script: %tempscript%
    if exist "%outputlog%" (
        echo Log: %outputlog%
    )
)

echo.
pause
