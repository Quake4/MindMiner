@echo off
:start
powershell -version 5.0 -executionpolicy bypass -command "&.\MindMiner.ps1"
if exist "bin\mm.new" (
	xcopy Bin\MM.New . /y /s /c /q /exclude:run.bat+.gitignore
	rmdir /q /s Bin\MM.New
	goto start:
) else (
	pause
)