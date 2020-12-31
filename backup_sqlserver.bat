@echo off

:: Set today's date variable
set today=%date:~0,2%-%date:~3,2%-%date:~6,4%

:: Get date 10 days ago on GDRIVE
set day=-10
echo >"%temp%\%~n0.vbs" s=DateAdd("d",%day%,now) : d=weekday(s)
echo>>"%temp%\%~n0.vbs" WScript.Echo year(s)^& right(100+month(s),2)^& right(100+day(s),2)
for /f %%a in ('cscript /nologo "%temp%\%~n0.vbs"') do set "result=%%a"
del "%temp%\%~n0.vbs"
set "YYYY=%result:~0,4%"
set "MM=%result:~4,2%"
set "DD=%result:~6,2%"
set "MYOLDDATEGDRIVE=%yyyy%-%mm%-%dd%"

:: Create temporary local folder
mkdir %systemdrive%\TMPSQL >nul 2>&1

:: Set folder root of backup files to send to network and to GDRIVE
set BACKUPPATHROOT=%systemdrive%\TMPSQL

:: Create local folder from date
mkdir %BACKUPPATHROOT%\%today% >nul 2>&1

:: Set local folder to save backup files
set BACKUPPATH=%BACKUPPATHROOT%\%today%

:: Set SQL Server location
set SERVERNAME=localhost

:: Set network folder mapping letter
set "LETTERBKPNET=S:"

:: Set network folder path
set PATHBKPNET=\\192.168.1.1\Backup\

:: Set username for network folder
set PATHBKPNETUSER=backupuser

:: Set password for network folder
set "PATHBKPNETPASS=backuppass"

:: Get password of backup file compress
set "PSWDZIP=senhadoarquivocompactado"

:: Build a list of databases to backup
set DBList=%BACKUPPATH%\SQLDBList.txt
SqlCmd -E -S %SERVERNAME% -h-1 -W -Q "SET NoCount ON; SELECT Name FROM sys.databases WHERE [Name] NOT IN ('master','model','msdb','tempdb')" > "%DBList%"

:: Backing UP
For /f "tokens=*" %%i in (%DBList%) do (
	echo Fazendo backup do banco de dados %%i
	sqlcmd -E -S %SERVERNAME% -Q "BACKUP DATABASE [%%i] TO DISK=N'%BACKUPPATH%\%%i.bak' WITH NOFORMAT, NOINIT, NOREWIND, NOUNLOAD"
	7za a -r -tzip -bso0 -bsp0 -sdel -p%PSWDZIP% %BACKUPPATH%\%%i.bak.zip %BACKUPPATH%\%%i.bak
	echo.
)

:: Remove old backup files from GDRIVE
gdrive list --query "createdTime <= '%MYOLDDATEGDRIVE%' and mimeType = 'application/vnd.google-apps.folder'" > %BACKUPPATH%\sql_gdrive_old.txt
for /f "tokens=1,2" %a in ('type %BACKUPPATH%\sql_gdrive_old.txt') do set SQL_GDRIVE_OLD=%a
gdrive delete -r %SQL_GDRIVE_OLD% >nul 2>&1

:: Upload folder from backup to GDRIVE

gdrive upload --recursive %BACKUPPATH% >nul 2>&1

:: Mount folder of backup from network
net use %LETTERBKPNET% %PATHBKPNET% /USER:%PATHBKPNETUSER% %PATHBKPNETPASS% >nul 2>&1

:: Delete folder older than 5 days
forfiles /S /D -5 /P "%LETTERBKPNET%\" /M "*" /C "cmd /c IF @isdir==TRUE rd @path /S /Q" >nul 2>&1

:: Copy local backup files to network folder and delete local files
robocopy %BACKUPPATHROOT% %LETTERBKPNET%\ /MOVE /E /NP /R:5 /W:30 >nul 2>&1

:: Unmount folder of backup from network
net use %LETTERBKPNET% /delete >nul 2>&1
