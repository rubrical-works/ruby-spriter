@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: MP4 to Spritesheet Generator (Windows Batch)
:: ============================================================================
:: Creates a spritesheet from an MP4 video by extracting evenly distributed frames.
::
:: Usage:
::   create-spritesheet.cmd <video.mp4> [output.png] [framecount] [columns] [maxwidth] [padding] [bgcolor]
::
:: Parameters:
::   %1 - Input video file (required)
::   %2 - Output spritesheet file (default: spritesheet.png)
::   %3 - Number of frames to extract (default: 16)
::   %4 - Number of columns in grid (default: 4)
::   %5 - Maximum width per frame (default: 320)
::   %6 - Padding between frames (default: 5)
::   %7 - Background color (default: white)
::
:: Example:
::   create-spritesheet.cmd input.mp4
::   create-spritesheet.cmd input.mp4 output.png 20 5 480 10 black
:: ============================================================================

echo.
echo ========================================
echo MP4 to Spritesheet Generator
echo ========================================
echo.

:: Parse parameters with defaults
set "VIDEO_PATH=%~1"
set "OUTPUT_PATH=%~2"
set "FRAME_COUNT=%~3"
set "COLUMNS=%~4"
set "MAX_WIDTH=%~5"
set "PADDING=%~6"
set "BG_COLOR=%~7"

:: Set defaults if not provided
if "%VIDEO_PATH%"=="" (
    echo ERROR: No input video specified!
    echo.
    echo Usage: %~nx0 ^<video.mp4^> [output.png] [framecount] [columns] [maxwidth] [padding] [bgcolor]
    echo.
    echo Examples:
    echo   %~nx0 myvideo.mp4
    echo   %~nx0 myvideo.mp4 sprite.png 20 5 480 10 black
    exit /b 1
)

if "%OUTPUT_PATH%"=="" set "OUTPUT_PATH=spritesheet.png"
if "%FRAME_COUNT%"=="" set "FRAME_COUNT=16"
if "%COLUMNS%"=="" set "COLUMNS=4"
if "%MAX_WIDTH%"=="" set "MAX_WIDTH=320"
if "%PADDING%"=="" set "PADDING=5"
if "%BG_COLOR%"=="" set "BG_COLOR=white"

set "TEMP_DIR=temp_frames_%RANDOM%"

echo Input Video:  %VIDEO_PATH%
echo Output File:  %OUTPUT_PATH%
echo Frame Count:  %FRAME_COUNT%
echo Grid Layout:  %COLUMNS% columns
echo Frame Width:  %MAX_WIDTH%px
echo Padding:      %PADDING%px
echo Background:   %BG_COLOR%
echo.

:: Check if input file exists
if not exist "%VIDEO_PATH%" (
    echo ERROR: Input file not found: %VIDEO_PATH%
    exit /b 1
)

:: ============================================================================
:: Step 1: Check dependencies
:: ============================================================================
echo [1/5] Checking dependencies...

where ffmpeg >nul 2>&1
if errorlevel 1 (
    echo ERROR: ffmpeg not found!
    echo Install with: choco install ffmpeg
    exit /b 1
)

where ffprobe >nul 2>&1
if errorlevel 1 (
    echo ERROR: ffprobe not found!
    echo Install with: choco install ffmpeg
    exit /b 1
)

where magick >nul 2>&1
if errorlevel 1 (
    echo ERROR: ImageMagick not found!
    echo Install with: choco install imagemagick
    exit /b 1
)

echo       [OK] All dependencies found
echo.

:: ============================================================================
:: Step 2: Get video duration
:: ============================================================================
echo [2/5] Analyzing video...

for /f "delims=" %%i in ('ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "%VIDEO_PATH%" 2^>^&1') do set "DURATION=%%i"

if "%DURATION%"=="" (
    echo ERROR: Could not determine video duration
    exit /b 1
)

echo       Duration: %DURATION% seconds
echo.

:: ============================================================================
:: Step 3: Create temp directory
:: ============================================================================
echo [3/5] Creating temporary directory...

if exist "%TEMP_DIR%" (
    echo       Cleaning existing temp directory...
    rmdir /s /q "%TEMP_DIR%" 2>nul
)

mkdir "%TEMP_DIR%" 2>nul
if errorlevel 1 (
    echo ERROR: Could not create temp directory
    exit /b 1
)

echo       [OK] Created: %TEMP_DIR%
echo.

:: ============================================================================
:: Step 4: Extract frames using ffmpeg
:: ============================================================================
echo [4/5] Extracting %FRAME_COUNT% frames from video...

:: Calculate FPS for frame extraction
:: Using PowerShell for floating point division (more reliable than cmd math)
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "[Math]::Round(%FRAME_COUNT% / %DURATION%, 6)"`) do set "FPS=%%i"

echo       Calculated FPS: %FPS%
echo       Extracting frames...

ffmpeg -i "%VIDEO_PATH%" -vf "fps=%FPS%,scale=%MAX_WIDTH%:-1:flags=lanczos" -vsync 0 "%TEMP_DIR%\frame_%%04d.png" -hide_banner -loglevel error 2>&1

if errorlevel 1 (
    echo ERROR: Frame extraction failed
    goto :cleanup_error
)

:: Count extracted frames
set "EXTRACTED_COUNT=0"
for %%f in ("%TEMP_DIR%\*.png") do set /a EXTRACTED_COUNT+=1

if %EXTRACTED_COUNT% equ 0 (
    echo ERROR: No frames were extracted
    goto :cleanup_error
)

echo       [OK] Extracted %EXTRACTED_COUNT% frames
echo.

:: ============================================================================
:: Step 5: Create spritesheet using ImageMagick
:: ============================================================================
echo [5/5] Creating spritesheet...

:: Calculate rows
set /a "ROWS=(%EXTRACTED_COUNT% + %COLUMNS% - 1) / %COLUMNS%"

echo       Layout: %COLUMNS%x%ROWS% grid (%EXTRACTED_COUNT% frames)
echo       Building spritesheet...

magick montage "%TEMP_DIR%\*.png" -tile %COLUMNS%x%ROWS% -geometry +%PADDING%+%PADDING% -background %BG_COLOR% "%OUTPUT_PATH%" 2>nul

if errorlevel 1 (
    echo ERROR: Spritesheet creation failed
    goto :cleanup_error
)

if not exist "%OUTPUT_PATH%" (
    echo ERROR: Output file was not created
    goto :cleanup_error
)

:: Get output file size
for %%A in ("%OUTPUT_PATH%") do set "FILE_SIZE=%%~zA"
set /a "FILE_SIZE_MB=%FILE_SIZE% / 1048576"
set /a "FILE_SIZE_KB=%FILE_SIZE% / 1024"

if %FILE_SIZE_MB% gtr 0 (
    echo       [OK] Spritesheet created: %OUTPUT_PATH% ^(%FILE_SIZE_MB% MB^)
) else (
    echo       [OK] Spritesheet created: %OUTPUT_PATH% ^(%FILE_SIZE_KB% KB^)
)
echo.

:: ============================================================================
:: Cleanup
:: ============================================================================
:cleanup_success
echo [*] Cleaning up temporary files...
rmdir /s /q "%TEMP_DIR%" 2>nul
echo       [OK] Cleanup complete
echo.
echo ========================================
echo SUCCESS: Spritesheet generation complete!
echo ========================================
echo.
exit /b 0

:cleanup_error
echo.
echo [*] Cleaning up temporary files...
rmdir /s /q "%TEMP_DIR%" 2>nul
echo.
echo ========================================
echo ERROR: Spritesheet generation failed!
echo ========================================
echo.
exit /b 1
