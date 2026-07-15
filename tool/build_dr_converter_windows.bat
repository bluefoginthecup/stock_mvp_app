@echo off
setlocal

cd /d "%~dp0"

where py >nul 2>nul
if errorlevel 1 (
  echo Python launcher(py)를 찾을 수 없습니다.
  echo python.org에서 Python을 설치하고 "Add python.exe to PATH"를 체크하세요.
  pause
  exit /b 1
)

py -m pip --version >nul 2>nul
if errorlevel 1 (
  echo pip가 준비되지 않았습니다. pip를 설치합니다.
  py -m ensurepip --upgrade
)

py -m pip install --upgrade pip
py -m pip install -r dr_converter_requirements.txt
py -m PyInstaller dr_converter_windows.spec

echo.
echo 완료: dist\경영박사변환기.exe
pause
