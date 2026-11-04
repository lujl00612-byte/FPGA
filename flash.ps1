param([string]$EfinityHome='E:\Efinity 2026',[string]$Python='C:\Python314\python.exe')
$ErrorActionPreference='Stop'
$env:PYTHONUTF8='1'
Push-Location -LiteralPath $PSScriptRoot
$taskVariables=@('PROCESSOR_ARCHITECTURE','PYTHONIOENCODING','PYTHONHOME','EFINITY_HOME','EFXPGM_HOME','EFXDBG_HOME','EFXPT_HOME','EFINITY_USER_DIR_INI','Path')
$taskSaved=@{};foreach($taskName in $taskVariables){$taskSaved[$taskName]=[Environment]::GetEnvironmentVariable($taskName,'Process')}
try {
    & $Python tools/final_flash.py prepare
    if($LASTEXITCODE -ne 0){throw 'Identity preflight failed'}
    $taskRecord=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '.cache/flash-session.txt')).Trim()
    $taskPre=Get-Content -LiteralPath (Join-Path $taskRecord 'preflight.json') -Raw -Encoding utf8 | ConvertFrom-Json
    $taskPython=Join-Path $EfinityHome 'python311/bin/python.exe'
    $env:PROCESSOR_ARCHITECTURE='AMD64';$env:PYTHONIOENCODING='utf-8';$env:PYTHONHOME=Join-Path $EfinityHome 'python311'
    $env:EFINITY_HOME=$EfinityHome;$env:EFXPGM_HOME=Join-Path $EfinityHome 'pgm';$env:EFXDBG_HOME=Join-Path $EfinityHome 'debugger';$env:EFXPT_HOME=Join-Path $EfinityHome 'pt'
    $env:EFINITY_USER_DIR_INI=Join-Path $env:LOCALAPPDATA 'efinity/user_dir.ini'
    $env:Path=(Join-Path $EfinityHome 'python311/bin')+';'+(Join-Path $EfinityHome 'bin')+';'+(Join-Path $EfinityHome 'pgm/bin')+';'+(Join-Path $EfinityHome 'debugger/bin')+';'+$env:Path
    $taskHex=Join-Path $PSScriptRoot $taskPre.artifacts.hex.path;$taskBit=Join-Path $PSScriptRoot $taskPre.artifacts.bit.path
    $taskLoaded=$false
    try {
        & $taskPython tools/program_jtag_efinity2026.py --efinity-home $EfinityHome --jtag-frequency 3000000 (Join-Path $EfinityHome 'pgm/fli/titanium/u10660A79.bit') *> (Join-Path $taskRecord 'bridge-load.log')
        if($LASTEXITCODE -ne 0){throw 'Temporary bridge failed'}
        & $taskPython tools/program_flash_efinity2026.py --efinity-home $EfinityHome --jtag-frequency 3000000 $taskHex --operation read --address 0 --num-bytes $taskPre.backup_bytes --output-file .cache/flash-before.hex --expected-sha256 $taskPre.artifacts.hex.sha256 --result-file (Join-Path $taskRecord 'backup-read-result.json') *> (Join-Path $taskRecord 'backup-read.log')
        if($LASTEXITCODE -ne 0){throw 'Backup failed; Flash not overwritten'}
        & $taskPython tools/final_flash.py backup *> (Join-Path $taskRecord 'backup-save.log')
        if($LASTEXITCODE -ne 0){throw 'Backup save failed; Flash not overwritten'}
        & $taskPython tools/program_flash_efinity2026.py --efinity-home $EfinityHome --jtag-frequency 3000000 $taskHex --operation program --address 0 --expected-sha256 $taskPre.artifacts.hex.sha256 --result-file (Join-Path $taskRecord 'program-result.json') *> (Join-Path $taskRecord 'program.log')
        if($LASTEXITCODE -ne 0){throw 'Flash write/vendor check failed'}
        & $taskPython tools/program_jtag_efinity2026.py --efinity-home $EfinityHome --jtag-frequency 3000000 $taskBit *> (Join-Path $taskRecord 'activate.log')
        if($LASTEXITCODE -ne 0){throw 'Application load failed'}
        $taskLoaded=$true
        Start-Sleep -Seconds 3
        & $taskPython tools/initialize_debug_hub.py --efinity-home $EfinityHome --output (Join-Path $taskRecord 'debug-initialization.json') *> (Join-Path $taskRecord 'debug-initialization.log')
        if($LASTEXITCODE -ne 0){throw 'Default initialization failed'}
        & $taskPython tools/final_flash.py finish
        if($LASTEXITCODE -ne 0){throw 'Deployment record failed'}
    } finally {
        if(!$taskLoaded){& $taskPython tools/program_jtag_efinity2026.py --efinity-home $EfinityHome --jtag-frequency 3000000 $taskBit *> (Join-Path $taskRecord 'failure-restore-application.log')}
    }
} finally {
    foreach($taskName in $taskVariables){[Environment]::SetEnvironmentVariable($taskName,$taskSaved[$taskName],'Process')}
    Pop-Location
}
