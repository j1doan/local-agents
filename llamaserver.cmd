@echo off
setlocal enabledelayedexpansion

cd /d C:\llama.cpp || exit /b 1

set "MODELS_DIR=C:\models"
set "PRESETS_FILE=%~dp0models.ini"

echo.
echo 1) Start llama-server.exe (router mode)
echo 2) Start llama-benchmark.exe
echo.

set "choice="
set /p "choice=Select an option (1-2): "
if not defined choice (
    echo Invalid selection.
    exit /b 1
)

if "%choice%"=="1" goto :server
if "%choice%"=="2" goto :benchmark
echo Invalid selection.
exit /b 1

:server
echo Starting llama-server in router mode...
echo Presets file:    %PRESETS_FILE%
echo Max loaded models: 2
echo Tool calling: ENABLED (reasoning-budget=0, jinja=on)
echo.
echo Model management:
echo   List available models:  curl http://127.0.0.1:8080/models
echo   Load a model:          curl -X POST http://127.0.0.1:8080/models/load -H "Content-Type: application/json" -d "{\"model\": \"your-model.gguf\"}"
echo   Unload a model:        curl -X POST http://127.0.0.1:8080/models/unload -H "Content-Type: application/json" -d "{\"model\": \"your-model.gguf\"}"
echo.

start "" /D "C:\llama.cpp" llama-server.exe --host 127.0.0.1 --port 8080 --poll 100 --prio 2 --models-max 2 --models-preset "%PRESETS_FILE%"

echo Waiting for llama.cpp server...
timeout /t 10 /nobreak >nul
start http://127.0.0.1:8080
echo Llama server running at http://127.0.0.1:8080/v1
pause
exit /b 0

:benchmark
set "count=0"
for %%f in ("%MODELS_DIR%\*.gguf") do (
    set /a count+=1
    set "file_!count!=%%~nxf"
    set "size_!count!=%%~zf"
)

if !count! equ 0 (
    echo No GGUF files found in %MODELS_DIR%
    exit /b 1
)

echo Available GGUFs:
echo.
for /l %%i in (1,1,!count!) do (
    set "fname=!file_%%i!"
    set "fsize=!size_%%i!"
    set /a "fmb=!fsize! / 1048576"
    echo   %%i^) !fname!   !fmb! MB
)
echo.

set "idx="
set /p "idx=Select model (1-!count!): "
if not defined idx (
    echo Invalid selection.
    exit /b 1
)
if !idx! lss 1 (
    echo Invalid selection.
    exit /b 1
)
if !idx! gtr !count! (
    echo Invalid selection.
    exit /b 1
)

set "BENCH_MODEL=%MODELS_DIR%\!file_%idx%!"

echo.
set "ngl="
set /p "ngl=GPU layers (0=CPU only, 999=all): "
if not defined ngl set "ngl=999"
set "pp="
set /p "pp=Prompt tokens [512]: "
if not defined pp set "pp=512"
set "tg="
set /p "tg=Generate tokens [128]: "
if not defined tg set "tg=128"
set "reps="
set /p "reps=Repetitions [5]: "
if not defined reps set "reps=5"

echo.
echo Benchmarking: !file_%idx%!
echo   ngl=!ngl!  pp=!pp!  tg=!tg!  reps=!reps!
echo.

llama-benchmark.exe -m "%BENCH_MODEL%" -ngl !ngl! -t 4 -b 2048 -ub 512 -fa auto -ctk q8_0 -ctv q8_0 -p !pp! -n !tg! -r !reps! -o md --progress
exit /b 0
