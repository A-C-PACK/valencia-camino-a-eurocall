@echo off
REM Launch the game. Progress is saved automatically (Godot user data folder).
REM Godot is taken from tools\local.cmd if it exists (see tools\local.example.cmd),
REM otherwise "godot" must be on your PATH.
set "GODOT=godot"
if exist "%~dp0tools\local.cmd" call "%~dp0tools\local.cmd"
start "" "%GODOT%" --path "%~dp0game"
