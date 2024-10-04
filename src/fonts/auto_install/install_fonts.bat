FOR /F "delims=;" %%a IN ('Dir "../src" /B /A-D-H-S /S') DO (
    COPY "%%a" "%WINDIR%\Fonts"
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" /v "%%~nxa (TrueType)" /t REG_SZ /d "%%a" /f
)
