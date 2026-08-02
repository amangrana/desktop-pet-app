$ErrorActionPreference = "Stop"

$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sourcePath = Join-Path $PSScriptRoot "windows_fullscreen_helper_live_test.cs"
$helperPath = Join-Path $workspace (
    "platform\windows\fullscreen_helper\DesktopPetFullscreenHelper.exe"
)
$outputPath = Join-Path $env:TEMP "DesktopPetFullscreenHelperLiveTest.exe"
$compilerCandidates = @(
    "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)
$compilerPath = $compilerCandidates |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1

if (-not $compilerPath) {
    throw "The Windows .NET Framework C# compiler was not found."
}
if (-not (Test-Path -LiteralPath $helperPath)) {
    throw "The production fullscreen helper was not found."
}
if (Test-Path -LiteralPath $outputPath) {
    Remove-Item -LiteralPath $outputPath -Force
}

try {
    & $compilerPath `
        /nologo `
        /target:exe `
        /platform:x64 `
        /optimize+ `
        /checked+ `
        /reference:System.Windows.Forms.dll `
        /reference:System.Drawing.dll `
        "/out:$outputPath" `
        $sourcePath
    if ($LASTEXITCODE -ne 0) {
        throw "Fullscreen live test compilation failed with exit code $LASTEXITCODE."
    }

    & $outputPath $helperPath
    if ($LASTEXITCODE -ne 0) {
        throw "Fullscreen live test failed with exit code $LASTEXITCODE."
    }
}
finally {
    if (Test-Path -LiteralPath $outputPath) {
        Remove-Item -LiteralPath $outputPath -Force
    }
}
