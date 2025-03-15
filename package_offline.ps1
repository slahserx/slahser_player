# Slahser Player 离线打包脚本
Write-Host "Slahser Player 离线打包脚本" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

# 版本信息
$version = "0.8.0"

# 创建输出目录
if (-not (Test-Path "release")) {
    New-Item -Path "release" -ItemType Directory
}

# 应用程序名称
$appName = "Slahser Player"
$appNameNoSpace = "SlahserPlayer"

# 1. 创建临时目录
Write-Host "1. 创建临时打包目录..." -ForegroundColor Yellow
$tempDir = ".\temp_package"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -Path $tempDir -ItemType Directory

# 2. 复制构建好的应用程序文件
Write-Host "2. 复制构建好的应用程序文件..." -ForegroundColor Yellow
$buildDir = ".\frontend\build\windows\x64\runner\Release"
if (Test-Path $buildDir) {
    Copy-Item -Path "$buildDir\*" -Destination $tempDir -Recurse
} else {
    Write-Host "错误: 找不到构建目录 $buildDir" -ForegroundColor Red
    Write-Host "请先运行 'flutter build windows --release' 命令构建应用" -ForegroundColor Red
    exit 1
}

# 3. 创建安装脚本
Write-Host "3. 创建安装脚本..." -ForegroundColor Yellow
$installScript = @"
@echo off
echo 正在安装 $appName $version...
echo.

set INSTALL_DIR=%LOCALAPPDATA%\$appNameNoSpace

echo 创建安装目录: %INSTALL_DIR%
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

echo 复制文件...
xcopy /E /I /Y *.* "%INSTALL_DIR%"

echo 创建桌面快捷方式...
powershell -Command "& {`$WshShell = New-Object -ComObject WScript.Shell; `$Shortcut = `$WshShell.CreateShortcut('`$env:USERPROFILE\Desktop\$appName.lnk'); `$Shortcut.TargetPath = '`$env:LOCALAPPDATA\$appNameNoSpace\frontend.exe'; `$Shortcut.Save()}"

echo 创建开始菜单快捷方式...
powershell -Command "& {`$startMenu = [System.Environment]::GetFolderPath('Programs'); `$WshShell = New-Object -ComObject WScript.Shell; `$Shortcut = `$WshShell.CreateShortcut('`$startMenu\$appName.lnk'); `$Shortcut.TargetPath = '`$env:LOCALAPPDATA\$appNameNoSpace\frontend.exe'; `$Shortcut.Save()}"

echo.
echo 安装完成！
echo 您可以从桌面或开始菜单启动 $appName。
echo.
pause
"@

$installScript | Out-File -FilePath "$tempDir\安装.bat" -Encoding utf8

# 4. 创建卸载脚本
Write-Host "4. 创建卸载脚本..." -ForegroundColor Yellow
$uninstallScript = @"
@echo off
echo 正在卸载 $appName...
echo.

set INSTALL_DIR=%LOCALAPPDATA%\$appNameNoSpace

echo 删除桌面快捷方式...
del "%USERPROFILE%\Desktop\$appName.lnk" /Q

echo 删除开始菜单快捷方式...
powershell -Command "& {`$startMenu = [System.Environment]::GetFolderPath('Programs'); Remove-Item -Path '`$startMenu\$appName.lnk' -Force -ErrorAction SilentlyContinue}"

echo 删除安装文件...
rmdir "%INSTALL_DIR%" /S /Q

echo.
echo 卸载完成！
echo.
pause
"@

$uninstallScript | Out-File -FilePath "$tempDir\卸载.bat" -Encoding utf8

# 5. 创建自述文件
Write-Host "5. 创建自述文件..." -ForegroundColor Yellow
$readmeContent = @"
# $appName $version

## 安装说明

1. 双击"安装.bat"文件
2. 程序将自动安装到本地应用数据文件夹并创建快捷方式

## 卸载说明

1. 双击"卸载.bat"文件
2. 程序将自动卸载并移除所有快捷方式

## 更新内容

- 新增播放列表功能，支持创建、删除和编辑播放列表
- 优化音量控制，修复切换歌曲时音量滑块动画问题
- 改进用户界面，优化布局和响应式设计
- 新增迷你播放器模式，可在任务栏显示播放控制
- 添加更多音频格式支持，包括FLAC和OGG
- 修复多个已知BUG和稳定性问题

## 联系我们

GitHub: https://github.com/slahserx/slahser_player
"@

$readmeContent | Out-File -FilePath "$tempDir\自述文件.txt" -Encoding utf8

# 6. 创建发布包
Write-Host "6. 创建发布包..." -ForegroundColor Yellow
$zipFile = ".\release\${appNameNoSpace}_${version}_setup.zip"
if (Test-Path $zipFile) {
    Remove-Item -Path $zipFile -Force
}

Compress-Archive -Path "$tempDir\*" -DestinationPath $zipFile

# 7. 清理临时目录
Write-Host "7. 清理临时目录..." -ForegroundColor Yellow
Remove-Item -Path $tempDir -Recurse -Force

Write-Host "打包完成！" -ForegroundColor Green
Write-Host "发布文件位于: $zipFile" -ForegroundColor Green 