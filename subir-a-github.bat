@echo off
echo =======================================
echo    AnimaCine - Subiendo a GitHub...
echo =======================================
echo.

:: Entrar a la carpeta del proyecto
cd /d "%USERPROFILE%\Downloads\animacine"

:: Verificar que Git esta instalado
git --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: Git no esta instalado.
    echo Por favor instala Git desde https://git-scm.com/download/win
    pause
    exit /b
)

:: Inicializar repositorio Git
echo [1/5] Iniciando repositorio Git...
git init

:: Configurar rama principal
echo [2/5] Configurando rama main...
git branch -M main

:: Agregar todos los archivos
echo [3/5] Agregando archivos...
git add .

:: Hacer commit inicial
echo [4/5] Creando commit inicial...
git commit -m "feat: proyecto inicial AnimaCine"

:: Conectar con GitHub y subir
echo [5/5] Subiendo a GitHub...
git remote add origin https://github.com/FLIK29/animacine.git
git push -u origin main

echo.
echo =======================================
echo  Listo! Revisa tu repositorio en:
echo  https://github.com/FLIK29/animacine
echo =======================================
echo.
pause
