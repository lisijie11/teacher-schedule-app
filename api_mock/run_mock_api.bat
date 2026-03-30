@echo off
echo 启动教师教务系统Mock API服务...
echo.

REM 检查Python环境
python --version
if errorlevel 1 (
    echo 错误: 未检测到Python环境
    echo 请确保已安装Python 3.7+
    pause
    exit /b 1
)

REM 安装依赖
echo 正在检查并安装依赖...
pip install flask flask-cors --quiet

echo.
echo 启动Flask服务...
echo 按Ctrl+C停止服务
echo.
python mock_server.py

pause