@echo off
setlocal

set GDK=D:/Repo/sgdk
set GDK_WIN=D:\Repo\sgdk
set PATH=%GDK_WIN%\bin;%PATH%

%GDK_WIN%\bin\make.exe -f makefile.gen clean
if errorlevel 1 goto end

%GDK_WIN%\bin\make.exe -f makefile.gen

:end
endlocal