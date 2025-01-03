
# Credits: https://github.com/tomasklaen/uosc/blob/main/installers/windows.ps1

# Determine install directory
if (Test-Path env:MPV_CONFIG_DIR) {
    Write-Output "Installing into (MPV_CONFIG_DIR):"
    $ConfigDir = "$env:MPV_CONFIG_DIR"
} elseif (Test-Path "$PWD/portable_config") {
    Write-Output "Installing into (portable config):"
    $ConfigDir = "$PWD/portable_config"
} elseif ((Get-Item -Path $PWD).BaseName -eq "portable_config") {
    Write-Output "Installing into (portable config):"
    $ConfigDir = "$PWD"
} elseif (Test-Path env:MPVNET_HOME) {
    Write-Output "Installing into (MPVNET_HOME):"
    $ConfigDir = "$env:MPVNET_HOME"
} elseif (Test-Path "$env:APPDATA/mpv.net") {
    Write-Output "Installing into (current mpv.net user config):"
    $ConfigDir = "$env:APPDATA/mpv.net"
} elseif (Test-Path env:MPV_HOME) {
    Write-Output "Installing into (MPV_HOME):"
    $ConfigDir = "$env:MPV_HOME"
} elseif (Test-Path "$env:APPDATA/mpv") {
    Write-Output "Installing into (current mpv user config):"
    $ConfigDir = "$env:APPDATA/mpv"
} else {
    Write-Output "Installing into current directory:"
    $ConfigDir = "$PWD"
}

$ConfigDir = $ConfigDir -replace '/','\'
Write-Output "-> $ConfigDir"

# Ensure install directory exists
if (-not (Test-Path -Path $ConfigDir -PathType Container)) {
    if (Test-Path -Path $ConfigDir -PathType Leaf) {
        "Config directory is a file."
    }
    try {
        New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    }
    catch {
        "Couldn't create config directory."
    }
}

$ScriptFile = ($ConfigDir + '/scripts/command_palette.lua') -replace '/','\'
$ScriptFileURL = 'https://raw.githubusercontent.com/stax76/mpv-scripts/refs/heads/main/command_palette.lua'

$ExtendedScriptFile = ($ConfigDir + '/script-modules/extended-menu.lua') -replace '/','\'
$ExtendedMenuScriptURL = 'https://raw.githubusercontent.com/Seme4eg/mpv-scripts/refs/heads/master/script-modules/extended-menu.lua'

$ScriptsFolder = $ConfigDir + '/scripts/'

if (-not (Test-Path $ScriptsFolder)) {
    mkdir $ScriptsFolder
}

$ScriptModulesFolder = $ConfigDir + '/script-modules/'

if (-not (Test-Path $ScriptModulesFolder)) {
    mkdir $ScriptModulesFolder
}

# Download script
try {
    Invoke-WebRequest -OutFile $ScriptFile -Uri $ScriptFileURL | Out-Null
}
catch {
    "Couldn't download: $ScriptFileURL"
}

# Download menu library
try {
    Invoke-WebRequest -OutFile $ExtendedScriptFile -Uri $ExtendedMenuScriptURL | Out-Null
}
catch {
    "Couldn't download: $ExtendedMenuScriptURL"
}

$Bindings = @'
Ctrl+p      script-message-to command_palette show-command-palette "Command Palette" # Command Palette
F1          script-message-to command_palette show-command-palette "Bindings" # Bindings
F2          script-message-to command_palette show-command-palette "Properties" # Properties
F3          script-message-to command_palette show-command-palette "Commands" # Commands
F4          script-message-to command_palette show-command-palette "Options" # Options
F8          script-message-to command_palette show-command-palette "Playlist" # Playlist
F9          script-message-to command_palette show-command-palette "Tracks" # Tracks
Alt+a       script-message-to command_palette show-command-palette "Audio Tracks" # Audio Tracks
Alt+s       script-message-to command_palette show-command-palette "Subtitle Tracks" # Subtitle Tracks
Alt+b       script-message-to command_palette show-command-palette "Secondary Subtitle" # Secondary Subtitle
Alt+v       script-message-to command_palette show-command-palette "Video Tracks" # Video Tracks
Alt+c       script-message-to command_palette show-command-palette "Chapters" # Chapters
Alt+p       script-message-to command_palette show-command-palette "Profiles" # Profiles
Alt+d       script-message-to command_palette show-command-palette "Audio Devices" # Audio Devices
Alt+l       script-message-to command_palette show-command-palette "Subtitle Line" # Subtitle Line
Alt+t       script-message-to command_palette show-command-palette "Blu-ray Titles" # Blu-ray Titles
Alt+q       script-message-to command_palette show-command-palette "Stream Quality" # Stream Quality
Alt+r       script-message-to command_palette show-command-palette "Aspect Ratio" # Aspect Ratio
Alt+f       script-message-to command_palette show-command-palette "Recent Files" # Recent Files'
'@

# Edit input.conf
$InputConfPath = $ConfigDir + "/input.conf"

if (Test-Path $InputConfPath) {
    $InputConfContent = Get-Content $InputConfPath

    if (Test-Path $InputConfPath) {
        if (-not $InputConfContent -match 'show-command-palette') {
            $NewContent = $InputConfContent + "`r`n" + $Bindings
            $NewContent | Out-File $InputConfPath | Out-Null
        }
    }
} else {
    $Bindings | Out-File $InputConfPath | Out-Null
}

Write-Host "command_palette.lua was installed. Restart mpv/mpv.net. Show the command palette with Ctrl+P." -ForegroundColor Green
