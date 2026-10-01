@echo off
rem Build the Flecs static libraries from the amalgamated source in the submodule:
rem   flecs.lib   - release (/O2, FLECS_NDEBUG)
rem   flecs_d.lib - debug   (/Od /Z7, FLECS_DEBUG)
rem Requires the MSVC C++ build tools (Visual Studio or Build Tools for Visual Studio).
setlocal

set "ROOT=%~dp0.."
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

if not exist "%VSWHERE%" (
	echo Could not find vswhere.exe. Install Visual Studio ^(or the Build Tools^) with the C++ workload. 1>&2
	exit /b 1
)

set "VSPATH="
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSPATH=%%i"

if not defined VSPATH (
	echo Could not find a Visual Studio installation with the C++ tools. 1>&2
	exit /b 1
)

call "%VSPATH%\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1

if not exist "%ROOT%\build" mkdir "%ROOT%\build"

rem Report the exact toolchain, so the shipped binaries can be reproduced.
for /f "tokens=*" %%v in ('cl 2^>^&1 ^| findstr /C:"Compiler Version"') do echo %%v
for /f "tokens=*" %%v in ('link 2^>^&1 ^| findstr /C:"Linker Version"') do echo %%v

rem --- release -----------------------------------------------------------------
cl /nologo /c /O2 /DNDEBUG /I "%ROOT%\flecs\distr" "%ROOT%\flecs\distr\flecs.c" /Fo"%ROOT%\build\flecs.obj" || exit /b 1
lib /nologo /OUT:"%ROOT%\flecs.lib" "%ROOT%\build\flecs.obj" || exit /b 1
echo Built "%ROOT%\flecs.lib"

rem --- debug -------------------------------------------------------------------
rem FLECS_DEBUG is defined explicitly (the default runtime library is kept, so the debug
rem library links cleanly with Odin). /Z7 embeds debug info in the .lib itself.
cl /nologo /c /Od /Z7 /DFLECS_DEBUG /I "%ROOT%\flecs\distr" "%ROOT%\flecs\distr\flecs.c" /Fo"%ROOT%\build\flecs_d.obj" || exit /b 1
lib /nologo /OUT:"%ROOT%\flecs_d.lib" "%ROOT%\build\flecs_d.obj" || exit /b 1
echo Built "%ROOT%\flecs_d.lib"

rem --- sanitize ("debug++") -----------------------------------------------------
rem FLECS_SANITIZE implies FLECS_DEBUG and enables expensive checks.
cl /nologo /c /Od /Z7 /DFLECS_SANITIZE /I "%ROOT%\flecs\distr" "%ROOT%\flecs\distr\flecs.c" /Fo"%ROOT%\build\flecs_sanitize.obj" || exit /b 1
lib /nologo /OUT:"%ROOT%\flecs_sanitize.lib" "%ROOT%\build\flecs_sanitize.obj" || exit /b 1
echo Built "%ROOT%\flecs_sanitize.lib"
