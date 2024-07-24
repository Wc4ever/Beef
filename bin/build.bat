@ECHO --------------------------- Beef Build.Bat Version 5 ---------------------------

@SET P4_CHANGELIST=%1

PUSHD %~dp0..\

@SET MSBUILD_FLAGS=
@IF "%1" NEQ "clean" goto BUILD
@SET MSBUILD_FLAGS=/t:Clean,Build
@ECHO Performing clean build
:BUILD

@IF EXIST stats GOTO STATS_HAS
mkdir stats
:STATS_HAS

@IF EXIST BeefDep0_Done.txt GOTO DEPS0_HAS
@ECHO Downloading dependencies (LLVM)...
bin\curl.exe -O https://www.beeflang.org/BeefDep0.zip
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR
@ECHO Extracting dependencies (takes a while)...
bin\tar.exe -xf BeefDep0.zip
@IF %ERRORLEVEL% NEQ 0 GOTO
del BeefDep0.zip
:DEPS0_HAS

copy BeefLibs\SDL2\dist\SDL2.dll IDE\dist
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

CALL bin/msbuild.bat BeefySysLib\BeefySysLib.vcxproj /p:Configuration=Debug /p:Platform=x64 /p:SolutionDir=%cd%\ /v:m %MSBUILD_FLAGS%
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

CALL bin/msbuild.bat BeefySysLib\BeefySysLib.vcxproj /p:Configuration=Release /p:Platform=x64 /p:SolutionDir=%cd%\ /v:m %MSBUILD_FLAGS%
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

CALL bin/msbuild.bat IDEHelper\IDEHelper.vcxproj /p:Configuration=Debug /p:Platform=x64 /p:SolutionDir=%cd%\ /v:m %MSBUILD_FLAGS%
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

CALL bin/msbuild.bat IDEHelper\IDEHelper.vcxproj /p:Configuration=Release /p:Platform=x64 /p:SolutionDir=%cd%\ /v:m %MSBUILD_FLAGS%
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

CALL bin/build_rt.bat %1
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

CALL bin/msbuild.bat BeefBoot\BeefBoot.vcxproj /p:Configuration=Debug /p:Platform=x64 /p:SolutionDir=%cd%\ /v:m %MSBUILD_FLAGS%
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

CALL bin/msbuild.bat BeefBoot\BeefBoot.vcxproj /p:Configuration=Release /p:Platform=x64 /p:SolutionDir=%cd%\ /v:m %MSBUILD_FLAGS%
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

@ECHO Building BeefBuild_bootd
IDE\dist\BeefBoot_d.exe --out="IDE\dist\BeefBuild_bootd.exe" --src=IDE\src --src=BeefBuild\src --src=BeefLibs\corlib\src --src=BeefLibs\Beefy2D\src --src=BeefLibs\libgit2\src --define=CLI --define=DEBUG --startup=BeefBuild.Program --linkparams="Comdlg32.lib kernel32.lib user32.lib advapi32.lib shell32.lib IDE\dist\Beef042RT64_d.lib IDE\dist\IDEHelper64_d.lib IDE\dist\BeefySysLib64_d.lib"
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

@ECHO Building BeefBuild_boot
IDE\dist\BeefBoot.exe --out="IDE\dist\BeefBuild_boot.exe" --src=IDE\src --src=BeefBuild\src --src=BeefLibs\corlib\src --src=BeefLibs\Beefy2D\src --src=BeefLibs\libgit2\src --define=CLI --define=RELEASE --startup=BeefBuild.Program --linkparams="Comdlg32.lib kernel32.lib user32.lib advapi32.lib shell32.lib IDE\dist\Beef042RT64.lib IDE\dist\IDEHelper64.lib IDE\dist\BeefySysLib64.lib"
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

@ECHO Building BeefBuild_d
IDE\dist\BeefBuild_boot -proddir=BeefBuild -config=Debug
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

@ECHO Building BeefBuild
IDE\dist\BeefBuild_d -proddir=BeefBuild -config=Release
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

@ECHO Building IDE_bfd
@SET STATS_FILE=stats\IDE_Debug_build.csv
bin\RunWithStats IDE\dist\BeefBuild -proddir=IDE -clean -config=Debug_NoDeps
IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

@ECHO Building IDE_bf
@SET STATS_FILE=stats\IDE_Release_build.csv
bin\RunWithStats IDE\dist\BeefBuild -proddir=IDE -clean -config=Release
IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

@ECHO Building RandoCode
IDE\dist\BeefBuild_d -proddir=BeefTools\RandoCode -config=Release
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

@ECHO Building BeefPerf
IDE\dist\BeefBuild_d -proddir=BeefTools\BeefPerf -config=Release
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

@ECHO Building BeefCon
IDE\dist\BeefBuild_d -proddir=BeefTools\BeefCon -config=Release
@IF %ERRORLEVEL% NEQ 0 GOTO HADERROR

:SUCCESS
@ECHO SUCCESS!
@POPD
@EXIT /b 0

:HADERROR
@ECHO =================FAILED=================
@POPD
@EXIT /b %ERRORLEVEL%
