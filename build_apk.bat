@echo off
setlocal enabledelayedexpansion
echo ============================================
echo   W2D — Build APK release (Cameroun)
echo ============================================
echo.

REM ── 1. Flutter dispo ?
where flutter >nul 2>&1
if errorlevel 1 (
  echo ERREUR: Flutter non trouve dans PATH
  pause & exit /b 1
)

REM ── 2. Generer local.properties (chemin Flutter SDK)
for /f "tokens=*" %%i in ('flutter --version --machine 2^>nul ^| findstr /i "flutterRoot"') do (
  echo %%i
)
flutter config --no-analytics >nul 2>&1

REM Recuperer le chemin Flutter SDK
for /f "delims=" %%i in ('flutter --version 2^>&1') do (set FLUTTER_LINE=%%i & goto :found_flutter)
:found_flutter

REM Ecrire local.properties si absent
if not exist android\local.properties (
  echo Création de android\local.properties...
  for /f "usebackq delims=" %%f in (`where flutter`) do (
    set FLUTTER_EXE=%%f
    goto :got_path
  )
  :got_path
  REM Chemin du SDK = deux niveaux au-dessus de flutter.bat
  for %%d in ("!FLUTTER_EXE!\..\..") do set FLUTTER_SDK=%%~fd
  echo sdk.dir=%LOCALAPPDATA%\Android\Sdk> android\local.properties
  echo flutter.sdk=!FLUTTER_SDK!>> android\local.properties
  echo flutter.versionCode=1>> android\local.properties
  echo flutter.versionName=1.0.0>> android\local.properties
  echo [OK] local.properties cree.
)

REM ── 3. Nettoyage
echo [1/4] Nettoyage...
flutter clean

REM ── 4. Dependances
echo [2/4] Dependances...
flutter pub get
if errorlevel 1 (
  echo ERREUR: pub get echoue
  pause & exit /b 1
)

REM ── 5. Build APK ARM64 release (~20-25 MB)
echo [3/4] Build APK release ARM64...
flutter build apk --release --split-per-abi --target-platform android-arm64
if errorlevel 1 (
  echo.
  echo ERREUR: Build echoue. Conseils:
  echo  - Verifier que Android SDK est installe (Android Studio)
  echo  - Lancer: flutter doctor -v
  echo  - Verifier android\local.properties contient sdk.dir et flutter.sdk
  pause & exit /b 1
)

echo.
echo [4/4] APK genere!
echo.
echo   build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo.
for %%f in (build\app\outputs\flutter-apk\app-arm64-v8a-release.apk) do (
  set size=%%~zf
  set /a sizeMB=!size!/1048576
  echo   Taille : ~!sizeMB! MB
)

echo.
echo ============================================
echo   INSTALLATION:
echo.
echo   Cable USB (mode debug active):
echo     adb install build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo.
echo   Sans cable:
echo     Copier l'APK via USB, WhatsApp ou email
echo     Parametres > Securite > Sources inconnues > ON
echo     Ouvrir le fichier .apk sur le telephone
echo ============================================
pause
