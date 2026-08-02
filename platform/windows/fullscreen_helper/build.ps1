$ErrorActionPreference = "Stop"

$projectRoot = [IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..\..\..")
)
$sourcePath = Join-Path $PSScriptRoot "FullscreenHelper.cs"
$outputPath = Join-Path $PSScriptRoot "DesktopPetFullscreenHelper.exe"
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

& $compilerPath `
    /nologo `
    /target:winexe `
    /platform:x64 `
    /optimize+ `
    /checked+ `
    "/out:$outputPath" `
    $sourcePath

if ($LASTEXITCODE -ne 0) {
    throw "Fullscreen helper compilation failed with exit code $LASTEXITCODE."
}

$output = Get-Item -LiteralPath $outputPath
$hash = Get-FileHash -LiteralPath $outputPath -Algorithm SHA256
Write-Output (
    "Built {0} ({1} bytes, SHA256 {2}) for {3}" -f
    $output.FullName,
    $output.Length,
    $hash.Hash,
    $projectRoot
)
