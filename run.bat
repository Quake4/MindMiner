@echo off
cd /D "%~dp0"
if not exist "bin" (
	powershell -version 5.0 -executionpolicy bypass -noprofile -command "Get-ChildItem -File *.ps1 -Recurse | Unblock-File"
)
:start
powershell -version 5.0 -executionpolicy bypass -noprofile -command "&.\MindMiner.ps1"
if exist "bin\mm.new" (
	xcopy Bin\MM.New . /y /s /c /q /exclude:run.bat
	rmdir /q /s Bin\MM.New
	goto start:
) else if exist "bin\.stop" (
	rmdir /q /s Bin\.stop
	goto end:
)
goto start:
:end
pause