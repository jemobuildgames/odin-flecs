@echo off
rem Regenerate flecs.odin from the Flecs headers using odin-c-bindgen.
rem
rem The bindings are generated three times (release, debug, sanitize) and the variant-specific
rem struct layouts are merged into flecs.odin behind `when FLECS_SANITIZE` / `when ODIN_DEBUG`,
rem so the package matches flecs.lib, flecs_d.lib and flecs_sanitize.lib.
rem Requires Python 3 for the merge step.
setlocal

set "ROOT=%~dp0.."

if not exist "%ROOT%\build\bindgen.exe" (
	call "%~dp0build_bindgen.cmd" || exit /b 1
)

set "PYTHON=python"
where python >nul 2>nul || set "PYTHON=py -3"
%PYTHON% --version >nul 2>nul || (
	echo Python 3 is required for the build-variant merge step. 1>&2
	exit /b 1
)

rem 1) Release bindings -> flecs.odin
"%ROOT%\build\bindgen.exe" "%ROOT%\bindgen.sjson" || exit /b 1

rem 2) Debug bindings -> build\flecs_debug\flecs.odin
"%ROOT%\build\bindgen.exe" "%ROOT%\bindgen_debug.sjson" || exit /b 1

rem 3) Sanitize bindings -> build\flecs_sanitize\flecs.odin
"%ROOT%\build\bindgen.exe" "%ROOT%\bindgen_sanitize.sjson" || exit /b 1

rem 4) Make the variant-specific struct layouts conditional
%PYTHON% "%~dp0merge_build_variants.py" ^
	"%ROOT%\flecs.odin" ^
	"%ROOT%\build\flecs_debug\flecs.odin" ^
	"%ROOT%\build\flecs_sanitize\flecs.odin" || exit /b 1

echo Regenerated "%ROOT%\flecs.odin"
