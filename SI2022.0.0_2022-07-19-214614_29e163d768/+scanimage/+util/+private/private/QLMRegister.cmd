@echo off

set dllPath=%~dp0
set regasm64=%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\RegAsm.exe

REM reg query HKLM\SOFTWARE\Classes\CLSID\{0012593E-4A7F-4494-AA24-0F293A86DC1D} > nul 2> nul

REM if "%errorlevel%" EQU "0" goto END

REM --> reset error level
type nul>nul

REM --> Check for permissions
IF "%PROCESSOR_ARCHITECTURE%" EQU "amd64" (
    >nul 2>&1 "%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system"
) ELSE (
    >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
)

REM --> If error flag set, we do not have admin.
if "%errorlevel%" NEQ "0" (goto UACPrompt) else (goto gotAdmin)

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params= %*
    echo UAC.ShellExecute "cmd.exe", "/c ""%~f0"" %params:"=""%", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"

REM %regasm64% /unregister "%dllPath%\QlmLicenseLib.dll"
%regasm64% /codebase "%dllPath%\QlmLicenseLib.dll"

:END

