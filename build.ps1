param([string]$EfinityHome='E:\Efinity 2026',[string]$Python='C:\Python314\python.exe')
$ErrorActionPreference='Stop'
$env:PYTHONUTF8='1'
$taskRoot=$PSScriptRoot
if((Get-PSDrive H,V -ErrorAction SilentlyContinue)){throw 'H: or V: is occupied'}
Push-Location -LiteralPath $taskRoot
$taskXml=Join-Path $taskRoot 'ti60f225_oob.xml'
$taskBefore=[IO.File]::ReadAllBytes($taskXml)
$taskArch=$env:PROCESSOR_ARCHITECTURE;$taskOldHome=$env:EFINITY_HOME
$taskH=$false;$taskV=$false
try {
    & $Python tools/final_project.py begin
    if($LASTEXITCODE -ne 0){throw 'Dependency/input audit failed'}
    if(!$env:PROCESSOR_ARCHITECTURE){$env:PROCESSOR_ARCHITECTURE='AMD64'}
    $env:EFINITY_HOME=$null
    & subst H: $taskRoot;if($LASTEXITCODE -ne 0){throw 'H mapping failed'};$taskH=$true
    & subst V: $EfinityHome;if($LASTEXITCODE -ne 0){throw 'V mapping failed'};$taskV=$true
    Push-Location 'H:\'
    try {
        foreach($taskStage in @('map','interface','pnr','pgm')){
            $taskWork=if($taskStage -eq 'pgm'){'pnr'}else{$taskStage}
            $taskArgs=@('ti60f225_oob.xml','-f',$taskStage,'--family','Titanium','-d','Ti60F225','--timing_model','I3',
                '--output_dir','H:\.build','--work_dir',('H:\.build\work_'+$taskWork))
            if($taskStage -eq 'map'){$taskArgs+=@('--dir','H:\ip\csi_rx_controller','--dir','H:\ip\ddr3_official','--map_opts','veri_options=verilog_mode=sv_09,vhdl_mode=vhdl_2008','root=ti60f225_oob_top')}
            if($taskStage -eq 'interface'){$taskArgs+=@('--pt_opts','peri_file=H:\ti60f225_oob.peri.xml')}
            Write-Output ('V4-ddr1 direct build: '+$taskStage)
            & 'V:\bin\efx_run.bat' @taskArgs 2>&1 | Tee-Object -LiteralPath (Join-Path $taskRoot ('.build\'+$taskStage+'.log'))
            if($LASTEXITCODE -ne 0){throw ($taskStage+' failed')}
        }
    } finally {Pop-Location}
} finally {
    if($taskV){& subst V: /D};if($taskH){& subst H: /D}
    $env:PROCESSOR_ARCHITECTURE=$taskArch;$env:EFINITY_HOME=$taskOldHome
    $taskAfter=[IO.File]::ReadAllBytes($taskXml)
    if([Convert]::ToBase64String($taskBefore) -ne [Convert]::ToBase64String($taskAfter)){
        $taskA=[Xml.XmlDocument]::new();$taskB=[Xml.XmlDocument]::new();$taskA.PreserveWhitespace=$false;$taskB.PreserveWhitespace=$false
        $taskA.LoadXml([Text.Encoding]::UTF8.GetString($taskBefore));$taskB.LoadXml([Text.Encoding]::UTF8.GetString($taskAfter))
        if($taskA.OuterXml -ne $taskB.OuterXml){throw 'Project values changed; retained for review'}
        [IO.File]::WriteAllBytes($taskXml,$taskBefore)
    }
    Pop-Location
}
& $Python (Join-Path $taskRoot 'tools/final_project.py') finish
if($LASTEXITCODE -ne 0){throw 'Final build/timing failed'}
