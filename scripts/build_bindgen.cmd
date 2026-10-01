@echo off
rem Build the odin-c-bindgen generator into build\bindgen.exe.
rem Requires Odin and libclang (16 or newer). libclang.dll must be on PATH or LIBCLANG_PATH
rem must point at the folder containing it.
setlocal enabledelayedexpansion

set "ROOT=%~dp0.."
set "SRC=%ROOT%\odin-c-bindgen"
set "OUT=%ROOT%\build"
set "PATCH=%ROOT%\patches\odin-c-bindgen-record-definition.patch"

where odin >nul 2>nul || (echo odin was not found on PATH. 1>&2 & exit /b 1)

if not exist "%OUT%" mkdir "%OUT%"

rem --- locate libclang --------------------------------------------------------
set "LIBCLANG_DLL="
if defined LIBCLANG_PATH (
	if exist "%LIBCLANG_PATH%\libclang.dll" set "LIBCLANG_DLL=%LIBCLANG_PATH%\libclang.dll"
	if exist "%LIBCLANG_PATH%\bin\libclang.dll" set "LIBCLANG_DLL=%LIBCLANG_PATH%\bin\libclang.dll"
)
if not defined LIBCLANG_DLL (
	for /f "delims=" %%i in ('where libclang.dll 2^>nul') do (
		if not defined LIBCLANG_DLL set "LIBCLANG_DLL=%%i"
	)
)
if not defined LIBCLANG_DLL (
	echo Could not find libclang.dll. Install LLVM ^(16 or newer^) and add its bin folder to PATH. 1>&2
	exit /b 1
)

for %%i in ("%LIBCLANG_DLL%") do set "LIBCLANG_BIN=%%~dpi"
set "LIBCLANG_LIB=%LIBCLANG_BIN%..\lib\libclang.lib"
if not exist "%LIBCLANG_LIB%" set "LIBCLANG_LIB=%LIBCLANG_BIN%libclang.lib"
if not exist "%LIBCLANG_LIB%" (
	echo Could not find libclang.lib next to "%LIBCLANG_DLL%". 1>&2
	exit /b 1
)

copy /y "%LIBCLANG_LIB%" "%SRC%\libclang\libclang.lib" >nul || exit /b 1
copy /y "%LIBCLANG_DLL%" "%OUT%\libclang.dll" >nul || exit /b 1

rem --- apply the local generator fix (only needed until it lands upstream) -----
set "PATCH_APPLIED=0"
if exist "%PATCH%" (
	git -C "%SRC%" apply --check "%PATCH%" 2>nul
	if !errorlevel! equ 0 (
		git -C "%SRC%" apply "%PATCH%" || exit /b 1
		set "PATCH_APPLIED=1"
	) else (
		git -C "%SRC%" apply --reverse --check "%PATCH%" 2>nul
		if !errorlevel! neq 0 (
			echo Could not apply "%PATCH%". Update the odin-c-bindgen submodule and the patch. 1>&2
			exit /b 1
		)
	)
)

rem --- build ------------------------------------------------------------------
odin build "%SRC%\src" -out:"%OUT%\bindgen.exe"
set "BUILD_RESULT=%errorlevel%"

rem Restore the submodule so it does not show up as modified.
if "!PATCH_APPLIED!"=="1" git -C "%SRC%" checkout -- src/translate_collect.odin

if not "%BUILD_RESULT%"=="0" exit /b %BUILD_RESULT%
echo Built "%OUT%\bindgen.exe"
