param(
    [string] $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path $Root).Path
$RootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
$ConfigurationDir = Join-Path $RootFull 'src\Configuration'
$ImagesDir = Join-Path $RootFull 'src\Images'
$PlaybookConf = Join-Path $RootFull 'src\playbook.conf'

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Get-RelativePath {
    param([string] $Path)

    $full = [IO.Path]::GetFullPath($Path)
    if ($full.StartsWith($RootFull, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($RootFull.Length).TrimStart('\', '/')
    }
    return $Path
}

function Add-Error {
    param([string] $Message)
    $errors.Add($Message) | Out-Null
}

function Read-Text {
    param([string] $Path)
    return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}

function Test-XmlFile {
    param([string] $Path)

    try {
        $xml = New-Object xml
        $xml.PreserveWhitespace = $true
        $xml.Load($Path)
    } catch {
        Add-Error "$(Get-RelativePath $Path): invalid XML: $($_.Exception.Message)"
    }
}

function Test-JsonFile {
    param([string] $Path)

    try {
        $text = Read-Text $Path
        $json = [regex]::Replace($text, '(?m)^\s*//.*$', '')
        $json = [regex]::Replace($json, ',(\s*[\}\]])', '$1')
        $null = $json | ConvertFrom-Json
    } catch {
        Add-Error "$(Get-RelativePath $Path): invalid JSON/JSONC: $($_.Exception.Message)"
    }
}

function Get-PlaybookOptionMap {
    param([xml] $Conf)

    $options = @{}
    $featureOptions = @{}
    foreach ($node in $Conf.SelectNodes('//FeaturePages//*[local-name()="Name"]')) {
        $name = ($node.InnerText).Trim()
        if ($name.Length -eq 0) { continue }
        if ($featureOptions.ContainsKey($name)) {
            Add-Error "src/playbook.conf: duplicate feature option name '$name'"
        }
        $featureOptions[$name] = $true
        $options[$name] = $true
    }

    $softwareOptions = @{}
    foreach ($node in $Conf.SelectNodes('//Software/Package[@Option]')) {
        $name = ($node.Option).Trim()
        if ($name.Length -eq 0) { continue }
        if ($softwareOptions.ContainsKey($name)) {
            Add-Error "src/playbook.conf: duplicate software option name '$name'"
        }
        $softwareOptions[$name] = $true
        $options[$name] = $true
    }

    return $options
}

function Test-PlaybookConf {
    param([hashtable] $Options)

    if (!(Test-Path -LiteralPath $PlaybookConf -PathType Leaf)) {
        Add-Error 'src/playbook.conf: missing playbook.conf'
        return
    }

    try {
        $conf = New-Object xml
        $conf.PreserveWhitespace = $true
        $conf.Load($PlaybookConf)
    } catch {
        Add-Error "src/playbook.conf: invalid XML: $($_.Exception.Message)"
        return
    }

    foreach ($node in $conf.SelectNodes('//Software/Package/Icon')) {
        $iconName = ($node.InnerText).Trim()
        if ($iconName.Length -gt 0 -and !(Test-Path -LiteralPath (Join-Path $ImagesDir $iconName) -PathType Leaf)) {
            Add-Error "src/playbook.conf: missing icon file '$iconName'"
        }
    }

    foreach ($node in $conf.SelectNodes('//*[@DefaultOption]')) {
        $name = ($node.DefaultOption).Trim()
        if ($name.Length -gt 0 -and !$Options.ContainsKey($name)) {
            Add-Error "src/playbook.conf: DefaultOption references unknown option '$name'"
        }
    }
}

function Get-TaskReferences {
    param([string] $Text)

    $matches = [regex]::Matches($Text, "!task\s*:\s*\{[^}]*?\bpath\s*:\s*(['""])(.*?)\1", 'IgnoreCase')
    foreach ($match in $matches) {
        $match.Groups[2].Value.Trim()
    }
}

function Get-OptionReferences {
    param([string] $Text)

    $references = New-Object System.Collections.Generic.List[string]

    $optionMatches = [regex]::Matches($Text, '\boption\s*:\s*[''"]?(!?[A-Za-z0-9_.-]+)[''"]?', 'IgnoreCase')
    foreach ($match in $optionMatches) {
        $references.Add($match.Groups[1].Value) | Out-Null
    }

    $optionsMatches = [regex]::Matches($Text, '\boptions\s*:\s*\[([^\]]*)\]', 'IgnoreCase')
    foreach ($match in $optionsMatches) {
        $items = [regex]::Matches($match.Groups[1].Value, '[''"]?(!?[A-Za-z0-9_.-]+)[''"]?')
        foreach ($item in $items) {
            $references.Add($item.Groups[1].Value) | Out-Null
        }
    }

    return $references
}

function Test-YamlReferences {
    param([hashtable] $Options)

    if (!(Test-Path -LiteralPath $ConfigurationDir -PathType Container)) {
        Add-Error 'src/Configuration: missing configuration directory'
        return
    }

    $yamlFiles = Get-ChildItem -LiteralPath $ConfigurationDir -Recurse -File |
        Where-Object { $_.Extension -in @('.yml', '.yaml') } |
        Sort-Object FullName

    foreach ($file in $yamlFiles) {
        $text = Read-Text $file.FullName
        $relative = Get-RelativePath $file.FullName

        $seenTasks = @{}
        foreach ($taskPath in Get-TaskReferences $text) {
            $normalized = $taskPath.Replace('/', '\').Trim()
            if ($seenTasks.ContainsKey($normalized)) {
                Add-Error "${relative}: duplicate !task reference '$taskPath'"
            }
            $seenTasks[$normalized] = $true

            $target = Join-Path $ConfigurationDir $normalized
            if (!(Test-Path -LiteralPath $target -PathType Leaf)) {
                Add-Error "${relative}: referenced task does not exist: $taskPath"
            }
        }

        foreach ($optionRef in Get-OptionReferences $text) {
            $option = $optionRef.TrimStart('!')
            if ($option.Length -gt 0 -and !$Options.ContainsKey($option)) {
                Add-Error "${relative}: unknown option reference '$optionRef'"
            }
        }
    }
}

foreach ($file in Get-ChildItem -LiteralPath $RootFull -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' }) {
    switch -Regex ($file.Name) {
        'playbook\.conf$' { Test-XmlFile $file.FullName; break }
        '\.xml$' { Test-XmlFile $file.FullName; break }
        '\.json$' { Test-JsonFile $file.FullName; break }
    }
}

$confForOptions = $null
if (Test-Path -LiteralPath $PlaybookConf -PathType Leaf) {
    try {
        $confForOptions = New-Object xml
        $confForOptions.Load($PlaybookConf)
    } catch {
        $confForOptions = $null
    }
}

$options = @{}
if ($confForOptions -ne $null) {
    $options = Get-PlaybookOptionMap $confForOptions
}

Test-PlaybookConf $options
Test-YamlReferences $options

foreach ($warning in $warnings) {
    Write-Output "warning: $warning"
}

if ($errors.Count -gt 0) {
    [Console]::Error.WriteLine('Playbook validation failed:')
    foreach ($errorItem in $errors) {
        [Console]::Error.WriteLine("- $errorItem")
    }
    exit 1
}

$yamlCount = (Get-ChildItem -LiteralPath $ConfigurationDir -Recurse -File |
    Where-Object { $_.Extension -in @('.yml', '.yaml') }).Count
Write-Output "Validated $yamlCount YAML files plus JSON/XML assets with PowerShell checks."
exit 0
