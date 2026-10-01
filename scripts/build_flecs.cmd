@echo off
rem Build the Flecs static library (flecs.lib) from the amalgamated source in the submodule.
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

cl /nologo /c /O2 /DNDEBUG /I "%ROOT%\flecs\distr" "%ROOT%\flecs\distr\flecs.c" /Fo"%ROOT%\build\flecs.obj" || exit /b 1
lib /nologo /OUT:"%ROOT%\flecs.lib" "%ROOT%\build\flecs.obj" || exit /b 1

echo Built "%ROOT%\flecs.lib"
