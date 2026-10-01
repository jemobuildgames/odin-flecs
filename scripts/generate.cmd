@echo off
rem Regenerate flecs.odin from the Flecs headers using odin-c-bindgen.
rem
rem The bindings are generated twice (release and debug) and the debug-only struct layouts are
rem merged into flecs.odin behind `when ODIN_DEBUG`, so the package matches both flecs.lib and
rem flecs_d.lib. Requires Python 3 for the merge step.
setlocal

set "ROOT=%~dp0.."

if not exist "%ROOT%\build\bindgen.exe" (
	call "%~dp0build_bindgen.cmd" || exit /b 1
)

set "PYTHON=python"
where python >nul 2>nul || set "PYTHON=py -3"
%PYTHON% --version >nul 2>nul || (
	echo Python 3 is required for the debug/release merge step. 1>&2
	exit /b 1
)

rem 1) Release bindings -> flecs.odin
"%ROOT%\build\bindgen.exe" "%ROOT%\bindgen.sjson" || exit /b 1

rem 2) Debug bindings -> build\flecs_debug\flecs.odin (only used for the merge below)
"%ROOT%\build\bindgen.exe" "%ROOT%\bindgen_debug.sjson" || exit /b 1

rem 3) Make the debug-only struct layouts conditional on ODIN_DEBUG
%PYTHON% "%~dp0merge_debug_structs.py" "%ROOT%\flecs.odin" "%ROOT%\build\flecs_debug\flecs.odin" || exit /b 1

echo Regenerated "%ROOT%\flecs.odin"
