# Slahser Player Packaging Script (Inno Setup Version)
Write-Host "Slahser Player Packaging Script (Inno Setup Version)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Create release directory (if not exists)
if (-not (Test-Path "release")) {
    New-Item -Path "release" -ItemType Directory
    Write-Host "Created release directory" -ForegroundColor Yellow
}

# Check if flutter build is completed
$buildDir = ".\frontend\build\windows\x64\runner\Release"
if (-not (Test-Path "$buildDir\frontend.exe")) {
    Write-Host "Error: Flutter application build not found. Please build the app first." -ForegroundColor Red
    Write-Host "Run: cd frontend; flutter build windows --release" -ForegroundColor Yellow
    exit 1
}

# Create portable ZIP package
Write-Host "1. Creating portable ZIP package..." -ForegroundColor Yellow
$portableZip = ".\release\slahser_player_0.8.4_portable.zip"
if (Test-Path $portableZip) {
    Remove-Item -Path $portableZip -Force
}
Compress-Archive -Path "$buildDir\*" -DestinationPath $portableZip -Force
Write-Host "  Portable version created: $portableZip" -ForegroundColor Green

# Use Inno Setup to create installer
Write-Host "2. Creating installer with Inno Setup..." -ForegroundColor Yellow
$innoSetupCompiler = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $innoSetupCompiler)) {
    Write-Host "Error: Inno Setup compiler not found. Please make sure Inno Setup is installed." -ForegroundColor Red
    Write-Host "Download: https://jrsoftware.org/isdl.php" -ForegroundColor Yellow
    exit 1
}

& $innoSetupCompiler "installer.iss"
Write-Host "  Installer created: .\release\slahser_player_setup_0.8.4.exe" -ForegroundColor Green

# Update readme file in release folder
Write-Host "3. Updating installation instructions..." -ForegroundColor Yellow
$readmeContent = @"
# Slahser Player 0.8.4 Installation Guide

## Download Options

1. **Installer Version** (slahser_player_setup_0.8.4.exe): Standard Windows installer
   - Recommended for most users
   - Automatically creates Start Menu and desktop shortcuts
   - Can be uninstalled via Control Panel

2. **Portable Version** (slahser_player_0.8.4_portable.zip): No installation required
   - Extract and use
   - Perfect for USB drives or users who prefer not to install

## Installation Steps

### Installer Version

1. Double-click the downloaded `slahser_player_setup_0.8.4.exe` file
2. Follow the installation wizard instructions
3. After installation, launch the app from the Start Menu or desktop shortcut

### Portable Version

1. Download `slahser_player_0.8.4_portable.zip`
2. Extract to any folder
3. Double-click `frontend.exe` to launch the application

## Online Updates

Slahser Player has built-in online update functionality:

1. Open "Settings" in the application
2. Select the "About" tab
3. Click the "Check for Updates" button
4. Follow the prompts to download updates when available
"@

$readmeContent | Out-File -FilePath ".\release\install_readme.md" -Encoding utf8 -Force
Write-Host "  Installation guide updated" -ForegroundColor Green

# Done
Write-Host "`nPackaging completed!" -ForegroundColor Green
Write-Host "All files saved to 'release' directory:" -ForegroundColor Green
Write-Host "  - slahser_player_setup_0.8.4.exe (Installer)" -ForegroundColor Green
Write-Host "  - slahser_player_0.8.4_portable.zip (Portable Version)" -ForegroundColor Green
Write-Host "  - install_readme.md (Installation Guide)" -ForegroundColor Green 