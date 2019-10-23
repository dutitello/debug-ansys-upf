@echo off
setlocal EnableDelayedExpansion
cls

rem   These need to change, for each new release.  You might need to change
rem   the SetParameters function, if the compiler changes.  Otherwise, the
rem   rest of the script should not need changing.
rem
set "revn=194"
set "revndot=19.4"
set "ROOT_DIR=%AWP_ROOT194%"
set "IFORT_HOME=%IFORT_COMPILER17%"
set "VSVER=vs2017"


rem :::::::::::::::::::::::::::::::
rem ::                           ::
rem ::     E X E C U T I V E     ::
rem ::                           ::
rem :::::::::::::::::::::::::::::::

call :CheckEnvVars        ||  goto :MyExit
call :SetPlatformTarget   ||  goto :MyExit
call :SetParameters       ||  goto :MyExit
call :SetCompilerArgs     ||  goto :MyExit

call :CompileSourceFiles  ||  goto :MyExit

call :ShowBanner1

:REPEAT
call :ShowBanner2
call :PromptForName  ||  goto :MyExit

call :BuildCommonDll %SRCFILE%
call :BuildOtherDll  %SRCFILE%
goto :REPEAT

endlocal
goto :EOF


rem :::::::::::::::::::::::::::::::
rem ::                           ::
rem ::     F U N C T I O N S     ::
rem ::                           ::
rem :::::::::::::::::::::::::::::::

:CheckEnvVars
rem  check some basic environment variables
rem
   set "TXT1="
   set "TXT2="

   if not defined AWP_ROOT194 (
      set "TXT1=  I'm sorry, but environment variable AWP_ROOT%revn% does not exist."

   ) else if "%AWP_ROOT194%"=="" (
      set "TXT1=  I'm sorry, but environment variable AWP_ROOT%revn% exists, but is not set."

   ) else if not exist "%AWP_ROOT194%\ansys\bin\winx64\ansys.exe" (
      set "TXT1=  I'm sorry, but environment variable AWP_ROOT%revn% exists, and is set,"
      set "TXT2=  but it does not seem to point to a useful location."
   )

   if not "%TXT1%"==""  (
      echo.
      echo. %TXT1%
      if not "%TXT2%"==""  ( echo. %TXT2% )
      echo.  It should be set to the install location, of the ANSYS software.  For
      echo.  example:
      echo.
      echo.      C:\Program Files\ANSYS Inc\v%revn%
      echo.
      echo.  Please create/fix this variable, and then try again.
      echo.
      endlocal
      exit /B 1
   )
   exit /B 0


rem Nothing below this line needs to change, to revision this file

:SetPlatformTarget
   if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
      set "PLATFORM_DIR=winx64"
      set "IFORT_PLATFORM=intel64"
      set "MACHINE_TARGET=X64"

   ) else if "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
      set "PLATFORM_DIR=winx64"
      set "IFORT_PLATFORM=intel64"
      set "MACHINE_TARGET=X64"

   ) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
      set "PLATFORM_DIR=intel"
      set "IFORT_PLATFORM=ia32"
      set "MACHINE_TARGET=X86"
   )
   exit /B 0


:SetParameters
   rem "PLATFORM_DIR=winx64"
   rem "IFORT_PLATFORM=intel64"
   set "BIT_TARGET=64"

   call "%IFORT_HOME%\bin\compilervars.bat" %IFORT_PLATFORM% %VSVER%

rem  Some environment variables that the compiler will consult
rem
   set "AIDIR=%ROOT_DIR%\ansys\customize\Include"
   set "ALDIR=%ROOT_DIR%\ansys\Custom\Lib\%PLATFORM_DIR%"

   if exist "%AIDIR%\"  ( set "INCLUDE=%AIDIR%;%INCLUDE%" )
   if exist "%ALDIR%\"  ( set "LIB=%ALDIR%;%LIB%" )

   set /A FAIL_CNT    = 0
   set /A SUCCESS_CNT = 0
   exit /B 0


:SetCompilerArgs
   rem  command-line arguments, for the compiler lines
   rem
   set "COMMACS=/DNOSTDCALL /DARGTRAIL /DCADOE_ANSYS /DPCWINNT_SYS"
   set "CMACS=/DCURVEFIT_EXPORTS /D_X86=1 /DOS_WIN32 /DWIN32 /D__STDC__"
   set "FMACS=/D_EFL /DFORTRAN"
   set "MACS64=/DPCWIN64_SYS /DPCWINX64_SYS"

   set "COMSWITCH=/MD /c"
   set "CSWITCH=/Gy- /EHsc /Zi /W3"
   set "FSWITCH=/fpp /4Yportlib /auto /Fo.\ /watch:source"
   exit /B 0


:CompileSourceFiles
   rem  Just build them all at once
   del /q compile.log compile_error.txt >NUL 2>&1
   del /q link.log    link_error.txt    >NUL 2>&1

   if "%PLATFORM_DIR%"=="winx64" (
      if exist *.F    ( ifort /debug /Zi /warn:all /check:all /traceback /Qfp-stack-check /Od /wrap-margin- %COMMACS% %FMACS% %COMSWITCH% %FSWITCH% %MACS64% *.F   >>compile.log 2>&1 )
      if exist *.c    ( cl    %COMMACS% %CMACS% %COMSWITCH% %CSWITCH% %MACS64% *.c   >>compile.log 2>&1 )
      if exist *.cpp  ( cl    %COMMACS% %CMACS% %COMSWITCH% %CSWITCH% %MACS64% *.cpp >>compile.log 2>&1 )
   )

   if "%PLATFORM_DIR%"=="intel" (
      if exist *.F    ( ifort /debug /Zi /warn:all /check:all /traceback /Qfp-stack-check /Od /wrap-margin- %COMMACS% %FMACS% %COMSWITCH% %FSWITCH% /align:rec4byte *.F   >>compile.log 2>&1 )
      if exist *.c    ( cl    %COMMACS% %CMACS% %COMSWITCH% %CSWITCH% /Zp4            *.c   >>compile.log 2>&1 )
      if exist *.cpp  ( cl    %COMMACS% %CMACS% %COMSWITCH% %CSWITCH% /Zp4            *.cpp >>compile.log 2>&1 )
   )

   if exist compile.log (
      FINDSTR /I /C:": error" compile.log >compile_error.txt
      if !ERRORLEVEL!==0  (
         call :ShowBanner "UPF COMPILER ERROR!  Check compile.log for more information."
         exit /B 1
      )

      REM del /Q compile_error.txt
   )

   exit /B 0


rem  We have a feature, that implements a "common block" data storage area,
rem  for use by the DLLs.  If you are making use of this, then this must be
rem  built first, so it can be linked with the other DLLs.
rem
:BuildCommonDll
   set "SRC=%1"
   set "UPFFILE=%SRC%Lib"
   set "DLLFILE=%SRC%Lib.dll"

   rem  bail, if this isn't the common block file
   if /I not "%SRC%"=="userdata"  ( exit /B 0 )

   call :CheckForSource %SRC% "common-block"  ||  exit /B 1
   call :CheckForObject %SRC%                 ||  exit /B 1

   rem  clean-up, and prep for linking
   call :AssembleLinkerFile userdata

   rem  link it, into its' own DLL
   echo. ======================================== >> link.log
   echo. Linking %SRC% ... >> link.log
   link @%UPFFILE%.lrf >>     link.log 2>&1

   call :CheckOnLink !ERRORLEVEL! %SRC% %DLLFILE%
   echo.  >>                  link.log

   rem  get rid of this, so any further links won't use it
   del /q  userdata.obj >NUL 2>&1

   exit /B 0


rem  All other UPF DLLs are constructed here.
rem
:BuildOtherDll
   set "SRC=%1"
   set "UPFFILE=%SRC%Lib"
   set "DLLFILE=%SRC%Lib.dll"

   rem  bail, if they specified the common-block item
   if /I "%SRC%"=="userdata"  ( exit /B 0 )

   call :CheckForSource %SRC%     ||  exit /B 1
   call :CheckForObject %SRC%     ||  exit /B 1

   rem  Get rid of this, so any further links won't use it.
   rem  Yes, this was already done, in BuildCommonDll.  Do
   rem  it again, in case they tried to do things out-of-order.
   del /q  userdata.obj >NUL 2>&1

   rem  clean-up, and prep for linking
   call :AssembleLinkerFile %SRC%

   rem then link the DLL
   echo. ======================================== >> link.log
   echo. Linking %SRC% ... >> link.log
   link @%SRC%Lib.lrf >>      link.log 2>&1

   call :CheckOnLink !ERRORLEVEL! %SRC% %DLLFILE%
   echo.  >>                  link.log

   rem set ANS_USER_PATH=%CD%
   rem echo. *** ANS_USER_PATH: %ANS_USER_PATH% ***

   rem  get rid of these, or ansysNNN.exe will have a fit
   rem del /q compile_error.txt link_error.txt >NUL 2>&1
   exit /B 0


rem  Check if the item they specified has a corresponding source file
rem
:CheckForSource
   set "MYSRC=%1"
   set "TXT=%2"

   rem  bail, if no source file
   if exist "%MYSRC%.F" (
      exit /B 0
   ) else if exist "%MYSRC%.c" (
      exit /B 0
   ) else if exist "%MYSRC%.cpp" (
      exit /B 0
   ) else (
      echo.
      echo. Sorry, the %TXT% source file, for %MYSRC%, is not here.
      echo.
      pause
      exit /B 1
   )

   exit /B 0


rem  Check if the item they specified compiled successfully
rem
:CheckForObject
   set "MYSRC=%1"

   rem  bail, if no object file
   if not exist "%MYSRC%.obj"    (
      echo.
      echo. Sorry, the source file, for %SRC%, did not compile.
      echo. See the file  compile.log, for compiler warnings and errors.
      echo.
      pause
      exit /B 1
   )

   exit /B 0


:CheckOnLink
   set /A "errlvl = %1"
   set "mysrc=%2"
   set "dll=%3"

   if %errlvl% GEQ 1  (
      call :ShowBanner "%dll% (%mysrc%) has FAILED to link"
      set /A FAIL_CNT += 1
      exit /B 1
   ) else if not exist "%dll%" (
      call :ShowBanner "%dll% (%mysrc%) has FAILED to link"
      set /A FAIL_CNT += 1
      exit /B 1
   )

   call :ShowBanner "%dll% (%mysrc%) has been successfully built."
   set /A SUCCESS_CNT += 1
   exit /B 0


:AssembleLinkerFile
   rem  clean old linker files, and create new ones
   set "SRC=%1"
   set "UPFFILE=%SRC%Lib"

   del /q  %UPFFILE%.lib %UPFFILE%.dll %UPFFILE%.lrf %UPFFILE%.map %UPFFILE%.def %UPFFILE%.exp >NUL 2>&1

   rem  The source file was already compiled, so just create
   rem  the exported-functions file, and the linker resource
   rem  file.
   set "EXFILE=%UPFFILE%ex.def"
   set "LRFFILE=%UPFFILE%.lrf"

   if /I not "%SRC%" == "userdata"  (
      echo EXPORTS> %EXFILE%
      echo.  >>     %EXFILE%
      echo %SRC%>>  %EXFILE%
      "%ROOT_DIR%\ansys\Custom\user\%PLATFORM_DIR%\upcase" %EXFILE%
   )

   echo -out:%UPFFILE%.dll>              %LRFFILE%
   if /I not "%SRC%" == "userdata"  (
      echo -def:%EXFILE%>>               %LRFFILE%
   )
   echo -dll>>                           %LRFFILE%
   echo -debug>>                         %LRFFILE%
   echo -machine:%MACHINE_TARGET%>>      %LRFFILE%
   echo -map>>                           %LRFFILE%

   echo -manifest:embed>>                %LRFFILE%
   echo -defaultlib:ANSYS.lib>>          %LRFFILE%
   if exist "userdataLib.lib"  (
      echo -defaultlib:userdataLib.lib>> %LRFFILE%
   )
   echo. >>                              %LRFFILE%
   if "%SRC%" == "userdata"  (
      echo userdata.obj>>                %LRFFILE%
   ) else (
      echo *.obj>>                       %LRFFILE%
   )

   exit /B 0


rem :::::::::::::::::::::::::::::::::::::::::::::::::
rem ::                                             ::
rem ::     Human - Machine Interface Functions     ::
rem ::                                             ::
rem :::::::::::::::::::::::::::::::::::::::::::::::::

:ShowBanner1
   echo.
   echo.    This is the Mechanical APDL %revndot% ANSUSERSHARED script.  It is used
   echo.    to build a DLL of User Programmable Features, for the M-APDL program.
   echo.
   echo.
   echo.          NOTE:  The user subroutine source file^(s^) are expected to
   echo.          reside in this directory.
   echo.
   exit /B 0

:ShowBanner2
   cls
   echo.
   echo. ANSYS now has a "common block" feature, so that DLLs can share
   echo. data between themselves.  If you want to use this, then select
   echo.        USERDATA
   echo. first, before any other selection.
   echo.
   echo.
   echo. Enter one of the following choices to create your
   echo. user-programmable feature DLL:
   echo.
   echo.   UANBEG, UANFIN, UCNVRG, UELMATX, UITBEG, UITFIN, ULDBEG, ULDFIN,
   echo.   USER_TBELASTIC, USER01, USER02, USER03, USER04, USER05, USER06,
   echo.   USER07, USER08, USER09, USER10, USERCNPROP USERCR, USERCREEP,
   echo.   USERCV, USERCZM, USERDATA, USERELEM, USERFLD, USERFREESTRAIN,
   echo.   USERFRIC, USERFX, USERHYPER, USERINISTATE, USERINTER, USERMAT,
   echo.   USERMATTH, USEROU, USERSWSTRAIN, USERTHSTRAIN, USERWEAR, USOLBEG,
   echo.   USOLFIN, USREFL, USRSHIFT, USRSURF116, USSBEG, USSFIN, UTIMEINC,
   echo.
   echo. Enter Carriage-Return (Enter^) to Quit.
   echo.
   echo. Enter a user-programmable feature source filename, without the file
   echo. extension.  For example: USERMAT or usermat.  The filename is case-
   echo. insensitive.
   echo.
   exit /B 0


:PromptForName
   set "SRCFILE="
   set "UPFFILE="
   set "DLLFILE="
   set /P "SRCFILE=Enter a user-programmable feature source filename: "

   rem trim any unneeded whitespace
   rem
rem   SetLocal EnableDelayedExpansion
rem   set Params=%SRCFILE%
rem   for /f "tokens=1*" %%a in ("!Params!") do EndLocal & set %1=%%b

rem   set "UPFFILE=%SRCFILE%Lib"
   if "%SRCFILE%"==""  ( goto :EOF )

rem   if not exist %SRCFILE%.F (
rem      echo.
rem      echo. %SRCFILE%.F Does Not Exist!
rem      echo.
rem      pause
rem   )
   exit /B 0


:ShowBanner
   echo.
   echo.   ************************************************************************
   echo.
   echo.       %1
   echo.
   echo.   ************************************************************************
   echo.
   exit /B 0


:MyExit
   set /A TTL = %FAIL_CNT% + %SUCCESS_CNT%

   echo.
   echo. Summary:
   echo.   Total items attempted: %TTL%
   echo.   Successful builds:     %SUCCESS_CNT%
   echo.   Failed     builds:     %FAIL_CNT%
   echo.

   if %TTL% equ 0  (
      endlocal
      goto :eof
   )

   if %FAIL_CNT% geq 1  (
      echo. Please fix the build failures, and then run this script again.
      echo.

      endlocal
      goto :eof
   )

   if %SUCCESS_CNT% geq 1  (
      echo.
      echo.   ************************************************************************
      echo.
      echo.   Set environment variable ANS_USER_PATH, to the directory where the
   )

   if %SUCCESS_CNT% equ 1  (
      echo.   new DLL file resides.  Then run ansys%revn%, to use your newly-
      echo.   generated user shared library.

   ) else if %SUCCESS_CNT% geq 2  (
      echo.   new DLL files reside.  Then run ansys%revn%, to use your newly-
      echo.   generated user shared libraries.
   )

   if %SUCCESS_CNT% geq 1  (
      echo.
      echo.   ************************************************************************
      echo.
   )

   rem  if nothing worked, then be silent

   endlocal
   goto :eof


