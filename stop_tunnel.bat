@echo off
echo [SSH Tunneling] Closing active SSH tunnel processes...

:: Terminate all running ssh.exe processes
taskkill /f /im ssh.exe

echo [SSH Tunneling] All SSH tunnels have been closed.
pause
