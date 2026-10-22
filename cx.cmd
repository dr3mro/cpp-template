@echo off
rem cx - build, test, run and check the project (cmd.exe wrapper).
rem
rem   cx <command> [preset] [target...] [options] [-- args]
rem
rem A thin wrapper: the implementation is cmake\cx\cx.cmake, the same one cx
rem and cx.ps1 run. This file only finds cmake and starts it from the project
rem root. When cmake is not on PATH, the copy that comes with Visual Studio is
rem used (found with vswhere, like scripts\new-project.ps1 does).
setlocal

set "ROOT=%~dp0"
pushd "%ROOT%" >nul

set "CMAKE=cmake"
where cmake >nul 2>nul
if not errorlevel 1 goto run

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not defined ProgramFiles(x86) goto no-cmake
if not exist "%VSWHERE%" goto no-cmake

for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -property installationPath`) do set "VS=%%i"
if not defined VS goto no-cmake

set "CMAKE=%VS%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
if not exist "%CMAKE%" goto no-cmake

:run
"%CMAKE%" -P "%ROOT%cmake\cx\cx.cmake" -- %*
set "CODE=%ERRORLEVEL%"
popd
exit /b %CODE%

:no-cmake
echo error: cmake was not found. Install CMake 3.25+ ^(winget install Kitware.CMake^), 1>&2
echo or the "C++ CMake tools for Windows" component of Visual Studio. 1>&2
popd
exit /b 1
