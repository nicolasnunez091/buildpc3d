@echo off
cd /d "%~dp0"
echo BUILDPC3D - Servicio Python de IA
if "%GROQ_API_KEY%"=="" echo AVISO: GROQ_API_KEY no configurada. Godot utilizara el clasificador local.
py backend\app.py
pause
