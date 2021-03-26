@echo off
cls

rem  These need to change, for each new release.  You might need to change
rem  the SetParameters function, if the compiler changes.  Otherwise, the
rem  rest of the script should not need changing.
rem
set "revndot=19.5"
set "revncust=2019 R3"
set "ROOT_DIR=%AWP_ROOT195%"
set "VSVER=vs2017"
set "IFORT_HOME=%IFORT_COMPILER17%"
set "VCINPATH=%VS2017INSTALLDIR%\VC\Tools\MSVC\14.10.25017"

rem  Yes, we are saving the current working directory, and we chdir back
rem  into it, at various points in this script.  Normally, this script is
rem  run from a cmd.exe prompt, and it works fine without this.  But, we
rem  have automated test scripts, that call this script, and things fail,
rem  if we don't explicitly move back into the working directory.
set "ACWORKDIR=%cd%"


rem :::::::::::::::::::::::::::::::
rem ::                           ::
rem ::     E X E C U T I V E     ::
rem ::                           ::
rem :::::::::::::::::::::::::::::::

call :SetParameters  ||  goto :END
call :ShowBanner     ||  goto :END
call :AskAboutAero   ||  goto :END
call :CompileStuff   ||  goto :END
call :LinkStuff      ||  goto :END
call :CopyDlls       ||  goto :END

goto :END


rem :::::::::::::::::::::::::::::::
rem ::                           ::
rem ::     F U N C T I O N S     ::
rem ::                           ::
rem :::::::::::::::::::::::::::::::

:SetParameters
   set "PLATFORM_DIR=winx64"
   set "IFORT_PLATFORM=intel64"
   set "BIT_TARGET=64"

   call "%IFORT_HOME%\bin\compilervars.bat" %IFORT_PLATFORM% %VSVER%

   set "INCLUDE=%ROOT_DIR%\ansys\customize\Include;%INCLUDE%"
   set "LIB=%ROOT_DIR%\ansys\Custom\Lib\%PLATFORM_DIR%;%LIB%"
   exit /B 0


:ShowBanner
   echo.
   echo.   ***********************************************************************
   echo.
   echo.   This is the Mechanical APDL revision %revncust% ANSCUST batch file.  It is
   echo.   used to link User Programmable Features, into versions of the M-APDL
   echo.   program, on Microsoft Windows %BIT_TARGET%-bit systems.
   echo.
   echo.                   ******   IMPORTANT !!!! ******
   echo.
   echo.   The provided user subroutine source files reside in this folder:
   echo.      {InstallDir}\customize\user\
   echo.
   echo.   Please copy the source file^(s^), that you wish to modify, from the above
   echo.   folder, into your working folder, to include them in your link.  ^(The
   echo.   default working folder is {InstallDir}\custom\user\%PLATFORM_DIR%\ .^)
   echo.
   echo.   If you want to use a different working folder, then also copy these other
   echo.   files, from the default working folder, to your actual working folder:
   echo.
   echo.      ANSCUST.BAT
   echo.      ansysex.def
   echo.      ansys.lrf files
   echo.      app.manifest
   echo.
   echo.   When you are done copying, run ANSCUST.BAT from your working folder.
   echo.
   echo.   ***********************************************************************
   pause
   exit /B 0


:AskAboutAero
   set "AERO=FALSE"
   set /A ECNT=10

:AAA1
   echo.
   set /P ANSW=Do you want to link the Wind Turbine Aeroelastic library with Mechanical APDL? (Y or N):

   if /I "%ANSW%"=="Y" (
      set "AERO=TRUE"
      exit /B 0

   ) else if /I "%ANSW%"=="N" (
      set "AERO=FALSE"
      exit /B 0

   ) else (
      set /a ECNT=ECNT-1

      if "%ECNT%"=="0"  (
         echo.
         echo. giving up ...
         echo.
         exit /B 1
      )

      echo.
      echo. Please answer Y or N
      echo.
   )

   goto :AAA1


:CompileStuff
   setlocal EnableDelayedExpansion
   cd "%ACWORKDIR%"

   del /q compile.log compile_error.txt  >NUL 2>&1

   if exist *.obj      ( del /Q *.obj      >NUL 2>&1 )
   if exist ANSYS.exe  ( del /Q ANSYS.exe  >NUL 2>&1 )
   if exist ANSYS.exp  ( del /Q ANSYS.exp  >NUL 2>&1 )
   if exist ANSYS.lib  ( del /Q ANSYS.lib  >NUL 2>&1 )
   if exist ANSYS.map  ( del /Q ANSYS.map  >NUL 2>&1 )

   REM Removed here /O2 from CSWITCH and FSWITCH
   set "CUSTMACROS=/DNOSTDCALL /DARGTRAIL /DPCWIN64_SYS /DPCWINX64_SYS /DPCWINNT_SYS /DCADOE_ANSYS"
   set "CMACS=/DCURVEFIT_EXPORTS /D_X86=1 /DOS_WIN32 /DWIN32 /D__STDC__"
   set "CSWITCH=/Gy- /EHsc /Zi  /c /W3 /MD"
   set "FMACS=/D__EFL /DFORTRAN"
   set "FSWITCH=/fpp /4Yportlib /auto /c /Fo.\ /MD /watch:source"

   REM ------------------------
   REM Create debug flags
   set "FDEBUG=/debug /Zi /warn:all /check:all /traceback /Qfp-stack-check /Od /wrap-margin-"
   REM ------------------------

   if exist *.F  (
      rem  The "logo" is the banner that the compilers print-out, when they first
      rem  start processing.  We only want to see that once, for each type of file
      rem  we process.
      rem
      set "LOGOMAC="

      for /F "usebackq tokens=*" %%P in ( `dir /B "*.F"` ) do (
         echo.
         echo. compiling Fortran file %%P
         echo.
         ifort !LOGOMAC! %FDEBUG% %CUSTMACROS% %FMACS% %FSWITCH% %%P >>compile.log  2>&1
         set "LOGOMAC=/nologo"
      )
   )


   if exist *.c  (
      set "LOGOMAC="

      for /F "usebackq tokens=*" %%P in ( `dir /B "*.c"` ) do (
         echo.
         echo. compiling C file %%P
         echo.
         cl !LOGOMAC! %CDEBUG% %CUSTMACROS% %CMACS% /D__MS_VC_INSTALL_PATH="%VCINPATH%" %CSWITCH% %%P >>compile.log 2>&1
         set "LOGOMAC=/nologo"
      )
   )


   if exist *.cpp  (
      set "LOGOMAC="

      for /F "usebackq tokens=*" %%P in ( `dir /B "*.cpp"` ) do (
         echo.
         echo. compiling C++ file %%P
         echo.
         rem cl !LOGOMAC! %CUSTMACROS% %CMACS% %CSWITCH% %%P >>compile.log 2>&1
         cl !LOGOMAC! %CDEBUG% %CUSTMACROS% %CMACS% /D__MS_VC_INSTALL_PATH="%VCINPATH%" %CSWITCH% %%P >>compile.log 2>&1
         set "LOGOMAC=/nologo"
      )
   )

   if not exist compile.log (
      echo.
      echo. no local files to compile - is this what you wanted?
      echo.
   ) else (
      findstr /I /C:": error" compile.log >compile_error.txt

      if !errorlevel!==0 (
         @echo off
         echo.
         echo.   ******************************************************************************
         echo.
         echo.     COMPILER ERROR!  CHECK compile.log FOR MORE INFORMATION
         echo.
         echo.
         echo.   ******************************************************************************
         echo.
         endlocal
         exit /B 1
      )
      del /Q compile_error.txt
   )

   endlocal
   exit /B 0


:LinkStuff
   cd "%ACWORKDIR%"

   if exist ANSYS.exe ( del /Q ANSYS.exe )

   if "%AERO%" == "TRUE" (
      type ansys.lrf >ansys.lrf.sav
      echo "%ROOT_DIR%\ansys\Custom\User\%PLATFORM_DIR%\Aeroelastic\*.obj">>ansys.lrf

      link @ansys.lrf 2>&1 |  findstr /V /R /c:"^ansyslib..lib.* LNK4099: PDB" /c:"^zlibwapi.lib.* LNK4099: PDB"
      type ansys.lrf.sav >ansys.lrf
      del /q ansys.lrf.sav

   ) else (

      link @ansys.lrf 2>&1 |  findstr /V /R /c:"^ansyslib..lib.* LNK4099: PDB" /c:"^zlibwapi.lib.* LNK4099: PDB"
   )

   if %ERRORLEVEL% GEQ 1 (
      set "ltxt=LINK ERROR!"
      set enum=1
   ) else if not exist ansys.exe (
      set "ltxt=LINK ERROR!"
      set enum=1
   ) else (
      set "ltxt=Link was successful!"
      set enum=0
   )

   echo.
   echo.      ************************************************************************
   echo.
   echo.          %ltxt%
   echo.
   echo.      ************************************************************************
   echo.

   exit /B %enum%


:CopyDlls
   rem  We offer this, because some customers have multiple versions of ANSYS/MAPDL
   rem  in their paths.  By copying libraries here, we guarantee that if they run
   rem  this custom version, it will link with the correct version of the libraries.
   rem
   cd "%ACWORKDIR%"

   echo.
   echo.      ************************************************************************
   echo.
   echo.      The next question will give you the opportunity to copy the necessary
   echo.      runtime DLLs.  Note, this only needs to be done once.  You can answer
   echo.      "N" for all subsequent invocations of %0.
   echo.
   echo.      ************************************************************************
   echo.

:CD1
   set /P "ANSW=Do you want to copy the runtime DLLs? (Y or N): "

   if /I "%ANSW%"=="Y" (
      copy /y "%ROOT_DIR%\ansys\Bin\%PLATFORM_DIR%\"*.dll .
      copy /y "%ROOT_DIR%\commonfiles\AAS\bin\%PLATFORM_DIR%\"*.dll .
      exit /B 0
   ) else if /I "%ANSW%"=="N" (
      exit /B 0
   ) else (
      echo.
      echo "Please answer Y or N!"
      echo.
      goto CD1
   )

   exit /B 0


:END
endlocal

