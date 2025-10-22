@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: Pure FFmpeg Spritesheet Generator
:: ============================================================================
:: Creates spritesheets from video using only ffmpeg
:: Supports background removal via chroma key
::
:: Usage:
::   create-spritesheet-ffmpeg.cmd <video.mp4> [output.png] [frames] [cols] [width] [padding] [bg_removal]
::
:: Parameters:
::   video.mp4    - Input video file
::   output.png   - Output spritesheet (default: spritesheet.png)
::   frames       - Number of frames to extract (default: 16)
::   cols         - Number of columns (default: 4)
::   width        - Frame width in pixels (default: 320)
::   padding      - Padding between frames (default: 5)
::   bg_removal   - Background color to remove: green|blue|black|white|none (default: none)
::
:: Examples:
::   create-spritesheet-ffmpeg.cmd myvideo.mp4
::   create-spritesheet-ffmpeg.cmd myvideo.mp4 output.png 20 5 480 10 green
::   create-spritesheet-ffmpeg.cmd animation.mp4 sprite.png 12 4 256 8 blue
:: ============================================================================

echo.
echo ========================================
echo FFmpeg Spritesheet Generator
echo ========================================
echo.

:: ============================================================================
:: Parse Parameters
:: ============================================================================

set "VIDEO_PATH=%~1"
set "OUTPUT_PATH=%~2"
set "FRAME_COUNT=%~3"
set "COLUMNS=%~4"
set "MAX_WIDTH=%~5"
set "PADDING=%~6"
set "BG_REMOVE=%~7"

:: Validate input
if "%VIDEO_PATH%"=="" (
    echo ERROR: No input video specified
    goto :usage
)

if not exist "%VIDEO_PATH%" (
    echo ERROR: Video file not found: %VIDEO_PATH%
    exit /b 1
)

:: Set defaults
if "%OUTPUT_PATH%"=="" set "OUTPUT_PATH=spritesheet.png"
if "%FRAME_COUNT%"=="" set "FRAME_COUNT=16"
if "%COLUMNS%"=="" set "COLUMNS=4"
if "%MAX_WIDTH%"=="" set "MAX_WIDTH=320"
if "%PADDING%"=="" set "PADDING=5"
if "%BG_REMOVE%"=="" set "BG_REMOVE=none"

:: Calculate rows
set /a "ROWS=(%FRAME_COUNT% + %COLUMNS% - 1) / %COLUMNS%"

:: Display configuration
echo Configuration:
echo   Input:      %VIDEO_PATH%
echo   Output:     %OUTPUT_PATH%
echo   Frames:     %FRAME_COUNT%
echo   Layout:     %COLUMNS%x%ROWS% grid
echo   Frame Size: %MAX_WIDTH%px wide
echo   Padding:    %PADDING%px
echo   BG Removal: %BG_REMOVE%
echo.

:: ============================================================================
:: Step 1: Check dependencies
:: ============================================================================

echo [1/2] Checking dependencies...
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

echo       [OK] ffmpeg found
echo.

:: ============================================================================
:: Step 2: Build filter chain and create spritesheet
:: ============================================================================

echo [2/2] Creating spritesheet...

:: Get video duration for FPS calculation
for /f "delims=" %%i in ('ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "%VIDEO_PATH%" 2^>^&1') do set "DURATION=%%i"

if "%DURATION%"=="" (
    echo ERROR: Could not determine video duration
    exit /b 1
)

echo       Video duration: %DURATION% seconds

:: Calculate FPS for frame extraction (using PowerShell for float math)
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "[Math]::Round(%FRAME_COUNT% / %DURATION%, 6)"`) do set "FPS=%%i"

echo       Extraction FPS: %FPS%
echo       Building filter chain...

:: Build the video filter chain
set "VFILTER=fps=%FPS%"

:: Add scaling
set "VFILTER=%VFILTER%,scale=%MAX_WIDTH%:-1:flags=lanczos"

:: Add background removal if specified
if /i "%BG_REMOVE%"=="green" (
    echo       Removing green background...
    set "VFILTER=%VFILTER%,chromakey=0x00FF00:0.3:0.2"
) else if /i "%BG_REMOVE%"=="blue" (
    echo       Removing blue background...
    set "VFILTER=%VFILTER%,chromakey=0x0000FF:0.3:0.2"
) else if /i "%BG_REMOVE%"=="black" (
    echo       Removing black background...
    set "VFILTER=%VFILTER%,colorkey=black:0.3:0.2"
) else if /i "%BG_REMOVE%"=="white" (
    echo       Removing white background...
    set "VFILTER=%VFILTER%,colorkey=white:0.3:0.2"
)

:: Add padding (using pad filter to add space around each frame)
if %PADDING% gtr 0 (
    set /a "PAD_W=%MAX_WIDTH% + %PADDING% * 2"
    set "VFILTER=%VFILTER%,pad=!PAD_W!:ih+%PADDING%*2:%PADDING%:%PADDING%:color=0x00000000"
)

:: Add tile filter to create the spritesheet
set "VFILTER=%VFILTER%,tile=%COLUMNS%x%ROWS%"

echo       Generating spritesheet...
echo.

:: Execute ffmpeg with the complete filter chain
ffmpeg -i "%VIDEO_PATH%" ^
    -vf "%VFILTER%" ^
    -frames:v 1 ^
    -y ^
    "%OUTPUT_PATH%" ^
    -hide_banner -loglevel warning 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: Spritesheet creation failed
    exit /b 1
)

if not exist "%OUTPUT_PATH%" (
    echo.
    echo ERROR: Output file was not created
    exit /b 1
)

:: Get output file size
for %%A in ("%OUTPUT_PATH%") do set "FILE_SIZE=%%~zA"
set /a "FILE_SIZE_MB=%FILE_SIZE% / 1048576"
set /a "FILE_SIZE_KB=%FILE_SIZE% / 1024"

echo.
echo ========================================
echo SUCCESS: Spritesheet created!
echo ========================================
if %FILE_SIZE_MB% gtr 0 (
    echo File: %OUTPUT_PATH% ^(%FILE_SIZE_MB% MB^)
) else (
    echo File: %OUTPUT_PATH% ^(%FILE_SIZE_KB% KB^)
)
echo Layout: %COLUMNS%x%ROWS% grid ^(%FRAME_COUNT% frames^)
echo.

exit /b 0

:: ============================================================================
:: Usage Information
:: ============================================================================
:usage
echo Usage: %~nx0 ^<video.mp4^> [output.png] [frames] [cols] [width] [padding] [bg_removal]
echo.
echo Parameters:
echo   video.mp4    - Input video file (required)
echo   output.png   - Output spritesheet (default: spritesheet.png)
echo   frames       - Number of frames to extract (default: 16)
echo   cols         - Number of columns (default: 4)
echo   width        - Frame width in pixels (default: 320)
echo   padding      - Padding between frames (default: 5)
echo   bg_removal   - Background removal: green^|blue^|black^|white^|none (default: none)
echo.
echo Background Removal Options:
echo   green  - Remove green screen (chroma key)
echo   blue   - Remove blue screen (chroma key)
echo   black  - Remove black background
echo   white  - Remove white background
echo   none   - No background removal
echo.
echo Examples:
echo   %~nx0 myvideo.mp4
echo   %~nx0 myvideo.mp4 output.png 20 5 480 10 green
echo   %~nx0 animation.mp4 sprite.png 12 4 256 8 blue
echo.
exit /b 1
