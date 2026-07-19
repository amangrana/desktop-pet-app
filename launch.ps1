param(
    [switch]$Editor
)

$projectDirectory = $PSScriptRoot
$projectGodot = Join-Path $projectDirectory ".tools\godot-4.7.1\Godot_v4.7.1-stable_win64.exe"
$godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1

if (Test-Path -LiteralPath $projectGodot) {
    $godotExecutable = (Resolve-Path -LiteralPath $projectGodot).Path
}
elseif ($null -ne $godotCommand) {
    $godotExecutable = $godotCommand.Source
}
else {
    throw "Godot was not found. Download Godot 4.7.1 from https://godotengine.org/download/windows/"
}

if ($Editor) {
    $arguments = "--editor --path `"$projectDirectory`""
}
else {
    $arguments = "--path `"$projectDirectory`""
}

Start-Process -FilePath $godotExecutable -ArgumentList $arguments -WindowStyle Normal
