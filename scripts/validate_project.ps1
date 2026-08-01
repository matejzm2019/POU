param(
    [string]$GodotExe = 'C:\Users\matej\Downloads\godot.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runId = "headless-validation-$PID-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff'))"
$profileRoot = Join-Path $projectRoot ".godot\$runId"
$env:APPDATA = Join-Path $profileRoot 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $profileRoot 'AppData\Local'
New-Item -ItemType Directory -Path $env:APPDATA, $env:LOCALAPPDATA -Force | Out-Null

$tests = @(
    @{ Name = 'phase1'; Scene = 'res://scripts/validate_phase1.tscn'; Marker = 'PHASE_1_SCENE_REGRESSION_OK' },
    @{ Name = 'phase3'; Scene = 'res://scripts/validate_phase3.tscn'; Marker = 'PHASE_3_HOMEWORK_CHASE_OK' }
)

try {
    foreach ($test in $tests) {
        $logPath = Join-Path $profileRoot "$($test.Name).log"
        $arguments = @(
            '--headless', '--path', $projectRoot,
            '--log-file', $logPath,
            $test.Scene, '--', '--phase2-test'
        )
        $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
        if (-not $process.WaitForExit(60000)) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            throw "$($test.Name) exceeded the 60-second validation limit."
        }
        $log = Get-Content -LiteralPath $logPath -Raw -Encoding UTF8
        Write-Output $log.TrimEnd()
        if ($process.ExitCode -ne 0) {
            throw "$($test.Name) exited with code $($process.ExitCode)."
        }
        if (-not $log.Contains($test.Marker)) {
            throw "$($test.Name) did not emit $($test.Marker)."
        }
    }
} finally {
    $expectedPrefix = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.godot\headless-validation-'))
    $resolvedProfile = [System.IO.Path]::GetFullPath($profileRoot)
    if ($resolvedProfile.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedProfile)) {
        Remove-Item -LiteralPath $resolvedProfile -Recurse -Force
    }
}
