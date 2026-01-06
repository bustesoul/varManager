@echo off
echo VarManager 死锁清理工具
echo ========================

echo 正在检查VarManager进程...
tasklist | findstr "varManager" > nul
if %errorlevel% == 0 (
    echo 发现VarManager进程，正在强制结束...
    taskkill /F /IM varManager.exe /T > nul 2>&1
    timeout /t 3 > nul
    echo 进程已结束。
) else (
    echo 未发现VarManager进程。
)

echo.
echo 正在清理临时文件...

if exist "varsForInstall.txt" (
    del "varsForInstall.txt" > nul 2>&1
    echo 已删除: varsForInstall.txt
)

if exist "*.lock" (
    del "*.lock" > nul 2>&1
    echo 已删除: 锁文件
)

if exist "*.tmp" (
    del "*.tmp" > nul 2>&1
    echo 已删除: 临时文件
)

echo.
echo 正在等待系统释放资源...
timeout /t 3 > nul

echo.
echo 死锁清理完成！
echo 现在可以重新启动VarManager。
echo.
pause