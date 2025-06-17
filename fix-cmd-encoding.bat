@echo off
echo 正在修复Windows命令行中文显示问题...

:: 临时设置
chcp 65001 >nul

:: 永久修复
reg add "HKCU\Console" /v "CodePage" /t REG_DWORD /d 65001 /f >nul
reg add "HKCU\Console" /v "FaceName" /t REG_SZ /d "Consolas" /f >nul
reg add "HKCU\Console" /v "FontFamily" /t REG_DWORD /d 54 /f >nul

:: 设置系统区域
reg add "HKCU\Control Panel\International" /v "Locale" /t REG_SZ /d "00000804" /f >nul
reg add "HKCU\Control Panel\International" /v "LocaleName" /t REG_SZ /d "zh-CN" /f >nul

echo ✅ 修复完成！请关闭所有命令行窗口并重新打开
timeout /t 5