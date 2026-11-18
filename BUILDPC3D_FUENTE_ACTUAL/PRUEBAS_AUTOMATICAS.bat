@echo off
setlocal
cd /d "%~dp0"
py -m unittest discover -s backend\tests -v
if errorlevel 1 goto fallo
py -m unittest discover -s tests -v
if errorlevel 1 goto fallo
where godot >nul 2>&1
if errorlevel 1 (
    echo Godot no esta en PATH. Ejecuta las pruebas Godot con la ruta completa a su ejecutable.
    goto fin
)
godot --headless --path godot --script res://tests/run_tests.gd
if errorlevel 1 goto fallo
:fin
echo Pruebas disponibles terminadas. Las pruebas graficas y HTTP se ejecutan por separado; ver docs\PRUEBAS.md.
pause
exit /b 0
:fallo
echo Fallaron pruebas. Si falta trimesh, instala: py -m pip install -r requirements-dev.txt
pause
exit /b 1
