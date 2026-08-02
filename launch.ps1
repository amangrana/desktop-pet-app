param(
    [switch]$Editor
)

$projectDirectory = $PSScriptRoot
$projectGodot = Join-Path $projectDirectory ".tools\godot-4.7.1\Godot_v4.7.1-stable_win64.exe"
$projectGodotConsole = Join-Path $projectDirectory ".tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe"
$godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1

if (Test-Path -LiteralPath $projectGodot) {
    $godotExecutable = (Resolve-Path -LiteralPath $projectGodot).Path
    if (Test-Path -LiteralPath $projectGodotConsole) {
        $godotImportExecutable = (Resolve-Path -LiteralPath $projectGodotConsole).Path
    }
    else {
        $godotImportExecutable = $godotExecutable
    }
}
elseif ($null -ne $godotCommand) {
    $godotExecutable = $godotCommand.Source
    $godotImportExecutable = $godotExecutable
}
else {
    throw "Godot was not found. Download Godot 4.7.1 from https://godotengine.org/download/windows/"
}

if ($Editor) {
    $arguments = "--editor --path `"$projectDirectory`""
}
else {
    $importArguments = "--headless --import --path `"$projectDirectory`""
    $importProcess = Start-Process `
        -FilePath $godotImportExecutable `
        -ArgumentList $importArguments `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    if ($importProcess.ExitCode -ne 0) {
        throw "Godot could not refresh the project resources (exit code $($importProcess.ExitCode))."
    }
    $arguments = "--path `"$projectDirectory`""
}

Start-Process -FilePath $godotExecutable -ArgumentList $arguments -WindowStyle Normal
