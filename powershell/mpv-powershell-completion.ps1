
# PowerShell command line completion for the mpv media player.

# It can be installed by dot sourcing it in the profile.

# Mit license.

$UpdatedOptions = New-Object Collections.Generic.List[Object]
$Options = New-Object Collections.Generic.List[Object]

Function Get-MD5Hash($inputString) {
    $MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $UTF8 = New-Object -TypeName System.Text.UTF8Encoding
    [BitConverter]::ToString($MD5.ComputeHash($UTF8.GetBytes($inputString))) -replace '-',''
}

Function SetOptions
{
    try
    {
        $version = mpv --version
    }
    catch
    {
        throw
    }

    $optionPath = Join-Path ([IO.Path]::GetTempPath()) ((Get-MD5Hash $version) + ".txt")

    if (Test-Path $optionPath)
    {
        $optionContent = Get-Content -Path $optionPath
    }
    else
    {
        $optionContent = mpv --no-config --list-options
        $optionContent | Out-File -FilePath $optionPath
    }

    foreach ($line in $optionContent)
    {
        $line = $line.Trim()

        if (-not $line.StartsWith("--"))
        {
            continue
        }

        $table = @{ value = ""; type = ""; choices = @() }

        if ($line.Contains(" "))
        {
            $table["name"] = $line.Substring(2, $line.IndexOf(" ") - 2)
            $value = $line.Substring($line.IndexOf(" ") + 1).Trim()

            if ($value.Contains("("))
            {
                $value = $value.Substring(0, $value.IndexOf("(")).TrimEnd()
            }

            $table["value"] = $value
        }
        else
        {
            $table["name"] = $line.Substring(2)
        }

        if ($value.StartsWith("Choices:"))
        {
            $table["type"] = "choice"
            $table["choices"] = $value.Substring(8).TrimStart() -split " "
        }

        switch ($table["name"]) {
            'vo' { $table["type"] = "choice"; $table["choices"] = @('gpu', 'gpu-next', 'direct3d') }
        }

        if ($value.StartsWith('Flag'))
        {
            $table['type'] = 'flag'
        }

        if ($value.Contains('[file]') -or $table["name"].Contains('-file'))
        {
            $table['type'] = 'file'
        }

        if ($table['type'] -eq 'flag')
        {
            $noTable = @{ name = 'no-' + $table['name'];
                          value = $table['value'];
                          type = $table['type'];
                          choices = @()
                        }
            $noTable2 = @{ name = $table['name'] + '=no';
                           value = $table['value'];
                           type = $table['type'];
                           choices = @()
                         }
            $yesTable = @{ name = $table['name'] + '=yes';
                           value = $table['value'];
                           type = $table['type'];
                           choices = @()
                         }
            $Options.Add($table)
            $Options.Add($noTable)
            $Options.Add($yesTable)
            $Options.Add($noTable2)
        }
        elseif ($table['type'] -eq 'choice')
        {
            foreach ($it in $table["choices"])
            {
                $choiceTable = @{ name = $table['name'] + '=' + $it;
                                  value = $table['value'];
                                  type = $table['type'];
                                  choices = @()
                                }
                $Options.Add($choiceTable)
            }
        }
        else
        {
            $Options.Add($table)
        }
    }
}

Function Update-Option($name)
{
    $newOptions = New-Object Collections.Generic.List[Object]

    foreach ($it in $Options)
    {
        $newOptions.Add($it)
    }

    foreach ($it in $newOptions)
    {
        if ($it['name'] -eq 'ao' -and -not $UpdatedOptions.Contains('ao'))
        {
            $output = mpv --ao=help | select -skip 1 | sls '^\s*([-\w]+)' -AllMatches |
                foreach { $_.matches.Groups[1].Value }
            $output += @('help')

            foreach ($ao in $output)
            {
                $Options.Add(@{ name = "ao=" + $ao; value = ""; type = ""; choices = @() })
            }

            $UpdatedOptions.Add('ao')
        }

        if ($it['name'] -eq 'profile' -and -not $UpdatedOptions.Contains('profile'))
        {
            $output = mpv --profile=help | select -skip 1 | sls '^\s*([-\w]+)' -AllMatches |
                foreach { $_.matches.Groups[1].Value }
            $output += @('help')

            foreach ($profile in $output)
            {
                $Options.Add(@{ name = "profile=" + $profile; value = ""; type = ""; choices = @() })
            }

            $UpdatedOptions.Add('profile')
        }

        if ($it['name'] -eq 'scale' -and -not $UpdatedOptions.Contains('scale'))
        {
            $output = mpv --scale=help | select -skip 1 | sls '^\s*([-\w]+)' -AllMatches |
                foreach { $_.matches.Groups[1].Value } | sort
            $output += @('help')

            foreach ($scale in $output)
            {
                $Options.Add(@{ name = "scale=" + $scale; value = ""; type = ""; choices = @() })
            }

            $UpdatedOptions.Add('scale')
        }

        if ($it['name'] -eq 'tscale' -and -not $UpdatedOptions.Contains('tscale'))
        {
            $output = mpv --tscale=help | select -skip 1 | sls '^\s*([-\w]+)' -AllMatches |
                foreach { $_.matches.Groups[1].Value } | sort
            $output += @('help')

            foreach ($tscale in $output)
            {
                $Options.Add(@{ name = "tscale=" + $tscale; value = ""; type = ""; choices = @() })
            }

            $UpdatedOptions.Add('tscale')
        }

        if ($it['name'] -eq 'error-diffusion' -and -not $UpdatedOptions.Contains('error-diffusion'))
        {
            $output = mpv --error-diffusion=help | select -skip 1 | sls '^\s*([-\w]+)' -AllMatches |
                foreach { $_.matches.Groups[1].Value } | sort
            $output += @('help')

            foreach ($errorDiffusion in $output)
            {
                $Options.Add(@{ name = "error-diffusion=" + $errorDiffusion; value = ""; type = ""; choices = @() })
            }

            $UpdatedOptions.Add('error-diffusion')
        }

        if ($it['name'] -eq 'hwdec' -and -not $UpdatedOptions.Contains('hwdec'))
        {
            $output = mpv --hwdec=help | select -skip 1 | sls '^\s*([-\w]+)' -AllMatches |
                foreach { $_.matches.Groups[1].Value }
            $output += @('help')
            $output = $output | select -unique | sort

            foreach ($hwdec in $output)
            {
                $Options.Add(@{ name = "hwdec=" + $hwdec; value = ""; type = ""; choices = @() })
            }

            $UpdatedOptions.Add('hwdec')
        }

        if ($it['name'] -eq 'audio-device' -and -not $UpdatedOptions.Contains('audio-device'))
        {
            $output = mpv --audio-device=help | select -skip 1 | sls "^\s*('\S+')" -AllMatches |
                foreach { $_.matches.Groups[1].Value }
            $output = $output | foreach { if ($_ -match "'\w+'") { $_ -replace "'", '' } else { $_ } }
            $output += @('help')

            foreach ($audioDevice in $output)
            {
                $Options.Add(@{ name = "audio-device=" + $audioDevice; value = ""; type = ""; choices = @() })
            }

            $UpdatedOptions.Add('audio-device')
        }

        if ($it['name'] -eq 'vulkan-device' -and -not $UpdatedOptions.Contains('vulkan-device'))
        {
            $output = mpv --vulkan-device=help | select -skip 1 | sls "^\s*('.+?')" -AllMatches |
                foreach { $_.matches.Groups[1].Value }
            $output = $output | foreach { if ($_ -match "'\w+'") { $_ -replace "'", '' } else { $_ } }

            foreach ($vulkanDevice in $output)
            {
                $Options.Add(@{ name = "vulkan-device=" + $vulkanDevice; value = ""; type = ""; choices = @() })
            }

            $UpdatedOptions.Add('vulkan-device')
        }
    }
}

Function Get-Completion($cursorPosition, $wordToComplete, $commandName)
{
    if ($Options.Count -eq 0)
    {
        SetOptions
    }

    if (-not $wordToComplete.Contains(' ') -or -not $wordToComplete.ToLower().Contains('mpv'))
    {
        return
    }

    if ($commandName.StartsWith('--'))
    {
        if ($commandName -eq '--ao=') { Update-Option 'ao' }
        if ($commandName -eq '--profile=') { Update-Option 'profile' }
        if ($commandName -eq '--hwdec=') { Update-Option 'hwdec' }
        if ($commandName -eq '--audio-device=') { Update-Option 'audio-device' }
        if ($commandName -eq '--scale=') { Update-Option 'scale' }
        if ($commandName -eq '--tscale=') { Update-Option 'tscale' }
        if ($commandName -eq '--error-diffusion=') { Update-Option 'error-diffusion' }
        if ($commandName -eq '--vulkan-device=') { Update-Option 'vulkan-device' }

        if ($commandName -like '--*-file*=')
        {
            return (gci -file).FullName | Resolve-Path -Relative |
                foreach { if ($_.Contains(' ')) { $commandName + "'$_'" } else { $commandName + $_ } }
        }

        if ($commandName -match '(--.+-file.*=)(.+)')
        {
            return (gci -file).FullName | Resolve-Path -Relative |
                where { $_.ToLower().Contains($Matches[2].ToLower()) } |
                foreach { if ($_.Contains(' ')) { $Matches[1] + "'$_'" } else { $Matches[1] + $_ } }
        }

        return $Options | where { ('--' + $_.name).Contains($commandName) } | foreach { '--' + $_.name }
    }
    elseif ($commandName -eq '')
    {
        return (gci).FullName | Resolve-Path -Relative
    }
    else
    {
        return (gci).FullName | Resolve-Path -Relative |
            where { $_.ToLower().Contains($commandName.ToLower()) }
    }
}

# commandName: --ao=
# wordToComplete: mpv --ao=
# cursorPosition: 9

# Get-Completion 9 'mpv --ao=' '--ao='
# Get-Completion 16 'mpv --test-file=' '--test-file='

Register-ArgumentCompleter -Native -CommandName mpv -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)

    Add-Content -Path E:\Desktop\completer.txt -Value ("commandName: $commandName`nwordToComplete: $wordToComplete`ncursorPosition: $cursorPosition`n") | Out-Null

    Get-Completion $cursorPosition "$wordToComplete" "$commandName" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Register-ArgumentCompleter -Native -CommandName mpvnet -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)

    Get-Completion $cursorPosition "$wordToComplete" "$commandName" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
