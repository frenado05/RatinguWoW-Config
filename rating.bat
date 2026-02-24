@echo off
chcp 65001 >nul
echo ========================================
echo    RatinguWoW - Обновление порогов
echo ========================================
echo.

:: Определяем путь к папке WoW
set "WOW_PATH="
if exist ".\Wow.exe" set "WOW_PATH=."
if exist ".\Wow-64.exe" set "WOW_PATH=."
if exist ".\UWow.exe" set "WOW_PATH=."
if exist ".\UWow-64.exe" set "WOW_PATH=."
if exist "..\Wow.exe" set "WOW_PATH=.."
if exist "..\Wow-64.exe" set "WOW_PATH=.."
if exist "..\UWow.exe" set "WOW_PATH=.."
if exist "..\UWow-64.exe" set "WOW_PATH=.."

if "%WOW_PATH%"=="" (
    echo [ОШИБКА] Не найден Wow.exe, Wow-64.exe, UWow.exe или UWow-64.exe
    echo Убедитесь, что батник лежит в папке с игрой World of Warcraft
    echo.
    pause
    exit /b
)

echo [OK] Папка игры найдена: %WOW_PATH%
echo.

:: Создаем папку аддона если её нет
set "ADDON_PATH=%WOW_PATH%\Interface\AddOns\RatinguWoWx100Plus"
if not exist "%ADDON_PATH%" (
    mkdir "%ADDON_PATH%"
    echo [OK] Создана папка аддона
) else (
    echo [OK] Папка аддона существует
)

echo.
echo Скачивание файла порогов...
echo.

:: Добавляем случайный параметр для обхода кэша CDN
set "RAND=%RANDOM%"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/frenado05/RatinguWoW-Config/main/thresholds.lua?r=%RAND%' -OutFile '%ADDON_PATH%\thresholds.lua'"

if %errorlevel% equ 0 (
    echo [УСПЕХ] Файл успешно обновлен!
    echo.
    echo Файл сохранен в: %ADDON_PATH%\thresholds.lua
    echo.
    echo Теперь перезагрузите интерфейс в игре:
    echo - Нажмите /reload и Enter
    echo - Или перезайдите в игру
) else (
    echo [ОШИБКА] Не удалось скачать файл
    echo Проверьте подключение к интернету
)

echo.
pause