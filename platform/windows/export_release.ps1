param(
    [string]$GodotPath = ".tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe",
    [string]$CredentialPath = "",
    [string]$OutputPath = "dist\DesktopPet.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = (Resolve-Path -LiteralPath (
    Join-Path $PSScriptRoot "..\.."
)).Path

$expectedClientId = (
    "1096439647356-f00etpkkj8g3chtcm7vq6qu75m08j18f" +
    ".apps.googleusercontent.com"
)
$clientId = [Environment]::GetEnvironmentVariable(
    "DESKTOP_PET_GOOGLE_CLIENT_ID",
    "Process"
)
$clientSecret = [Environment]::GetEnvironmentVariable(
    "DESKTOP_PET_GOOGLE_CLIENT_SECRET",
    "Process"
)
if (
    [string]::IsNullOrWhiteSpace($clientId) -or
    [string]::IsNullOrWhiteSpace($clientSecret)
) {
    if ([string]::IsNullOrWhiteSpace($CredentialPath)) {
        $credentialFile = Get-ChildItem -LiteralPath $projectRoot -File `
            -Filter "client_secret*.json" |
            Sort-Object -Property Name |
            Select-Object -First 1
        if ($null -eq $credentialFile) {
            throw (
                "No OAuth environment configuration or ignored " +
                "client_secret*.json was found."
            )
        }
        $CredentialPath = $credentialFile.FullName
    } elseif (-not [IO.Path]::IsPathRooted($CredentialPath)) {
        $CredentialPath = Join-Path $projectRoot $CredentialPath
    }
    $credentials = Get-Content -LiteralPath $CredentialPath -Raw |
        ConvertFrom-Json
    $installed = $credentials.installed
    if ($null -ne $installed) {
        $clientId = [string]$installed.client_id
        $clientSecret = [string]$installed.client_secret
    }
}
if (
    $clientId -ne $expectedClientId -or
    [string]::IsNullOrWhiteSpace($clientSecret)
) {
    throw "The OAuth configuration is not the expected Desktop client."
}

if (-not [IO.Path]::IsPathRooted($GodotPath)) {
    $GodotPath = Join-Path $projectRoot $GodotPath
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot console executable was not found: $GodotPath"
}
if (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $projectRoot $OutputPath
}
$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$previousClientId = [Environment]::GetEnvironmentVariable(
    "DESKTOP_PET_GOOGLE_CLIENT_ID",
    "Process"
)
$previousClientSecret = [Environment]::GetEnvironmentVariable(
    "DESKTOP_PET_GOOGLE_CLIENT_SECRET",
    "Process"
)
try {
    $env:DESKTOP_PET_GOOGLE_CLIENT_ID = $clientId
    $env:DESKTOP_PET_GOOGLE_CLIENT_SECRET = $clientSecret
    & $GodotPath --headless --path $projectRoot `
        --export-release "Windows Desktop" $OutputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Godot export failed with exit code $LASTEXITCODE."
    }
} finally {
    [Environment]::SetEnvironmentVariable(
        "DESKTOP_PET_GOOGLE_CLIENT_ID",
        $previousClientId,
        "Process"
    )
    [Environment]::SetEnvironmentVariable(
        "DESKTOP_PET_GOOGLE_CLIENT_SECRET",
        $previousClientSecret,
        "Process"
    )
}

Write-Host "Windows release exported to $OutputPath"
