@echo off
setlocal
set "DIR=%~dp0"
set "MAVEN_EXE=%DIR%\.mvn\wrapper\apache-maven-3.9.6\bin\mvn.cmd"

if exist "%MAVEN_EXE%" (
    "%MAVEN_EXE%" %*
) else (
    echo Downloading Apache Maven 3.9.6...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('https://archive.apache.org/dist/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.zip', '%DIR%\.mvn\wrapper\apache-maven-3.9.6-bin.zip')"
    powershell -Command "Expand-Archive -Path '%DIR%\.mvn\wrapper\apache-maven-3.9.6-bin.zip' -DestinationPath '%DIR%\.mvn\wrapper' -Force"
    "%MAVEN_EXE%" %*
)
