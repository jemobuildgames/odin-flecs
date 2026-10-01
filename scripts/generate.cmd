@echo off
rem Regenerate flecs.odin from the Flecs headers using odin-c-bindgen.
setlocal

set "ROOT=%~dp0.."

if not exist "%ROOT%\build\bindgen.exe" (
	call "%~dp0build_bindgen.cmd" || exit /b 1
)

"%ROOT%\build\bindgen.exe" "%ROOT%\bindgen.sjson" || exit /b 1
echo Regenerated "%ROOT%\flecs.odin"
