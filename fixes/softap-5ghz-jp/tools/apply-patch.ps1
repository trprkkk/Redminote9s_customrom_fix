param(
    [Parameter(Mandatory = $true)][string]$Orig,
    [Parameter(Mandatory = $true)][string]$Baksmali,
    [Parameter(Mandatory = $true)][string]$Smali,
    [string]$Out = 'miui-wifi-service-patched.jar',
    [string]$Patch
)

# Rebuild a patched miui-wifi-service.jar from the original jar (Windows / PowerShell).
# Requires: Java, baksmali.jar, smali.jar
#   https://github.com/JesusFreke/smali/releases/tag/v2.5.2
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools/apply-patch.ps1 `
#     -Orig miui-wifi-service.jar `
#     -Baksmali baksmali-2.5.2.jar `
#     -Smali smali-2.5.2.jar `
#     -Out miui-wifi-service-patched.jar

$ErrorActionPreference = 'Stop'

if (-not $Patch) {
    $Patch = Join-Path $PSScriptRoot '..\patches\softap-5ghz-jp.patch'
}

if (-not (Test-Path $Orig)) { throw "not found: $Orig" }
if (-not (Test-Path $Baksmali)) { throw "not found: $Baksmali" }
if (-not (Test-Path $Smali)) { throw "not found: $Smali" }

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("softap-patch-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

try {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # 1. Extract classes.dex and MANIFEST.MF from the original jar
    $origDir = Join-Path $work 'orig'
    New-Item -ItemType Directory -Force -Path $origDir | Out-Null
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $Orig))
    try {
        foreach ($name in @('classes.dex', 'META-INF/MANIFEST.MF')) {
            $entry = $zip.GetEntry($name)
            if (-not $entry) { throw "entry not found in jar: $name" }
            $dest = Join-Path $origDir ($name -replace '/', '\')
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
        }
    }
    finally {
        $zip.Dispose()
    }

    # 2. Disassemble
    $smaliDir = Join-Path $work 'smali'
    & java -jar $Baksmali d (Join-Path $origDir 'classes.dex') -o $smaliDir
    if ($LASTEXITCODE -ne 0) { throw "baksmali failed ($LASTEXITCODE)" }

    # 3. Apply the same edits as patches/softap-5ghz-jp.patch
    $utf8 = New-Object System.Text.UTF8Encoding($false)

    $apManager = Join-Path $smaliDir 'com\android\server\wifi\sap\MiuiWifiApManager.smali'
    $text = [System.IO.File]::ReadAllText($apManager)
    $pattern = '(?s)\.method private updateCurrentCountryCode\(\)Ljava/lang/String;.*?\.end method'
    $replacement = @'
.method private updateCurrentCountryCode()Ljava/lang/String;
    .registers 7

    const-string v1, "INVALID"

    return-object v1
.end method
'@
    $new = [regex]::Replace($text, $pattern, $replacement.Replace("`r`n", "`n"))
    if ($new -eq $text) { throw 'failed to patch MiuiWifiApManager.updateCurrentCountryCode' }
    [System.IO.File]::WriteAllText($apManager, $new, $utf8)

    $targets = @(
        (Join-Path $smaliDir 'com\android\server\wifi\MiuiWifiService.smali'),
        (Join-Path $smaliDir 'com\android\server\wifi\AmlMiuiWifiServiceImp.smali')
    )
    foreach ($file in $targets) {
        $text = [System.IO.File]::ReadAllText($file)
        $pattern = '(?m)^\.method public isSapSupportedBand\(I\)Z\r?\n    \.registers 14\r?\n    \.param p1, "band"    # I\r?\n'
        $insert = ".method public isSapSupportedBand(I)Z`n    .registers 14`n    .param p1, `"band`"    # I`n`n    const/4 v0, 0x1`n`n    return v0`n"
        if (-not [regex]::IsMatch($text, $pattern)) { throw "isSapSupportedBand not found: $file" }
        $new = [regex]::Replace($text, $pattern, $insert)
        [System.IO.File]::WriteAllText($file, $new, $utf8)
    }

    # 4. Assemble
    $newDex = Join-Path $work 'classes.dex'
    & java -jar $Smali a $smaliDir -o $newDex
    if ($LASTEXITCODE -ne 0) { throw "smali failed ($LASTEXITCODE)" }

    # 5. Repack (entry paths use '/')
    $outFull = [System.IO.Path]::GetFullPath($Out)
    if (Test-Path $outFull) { Remove-Item $outFull -Force }
    $stream = [System.IO.File]::Open($outFull, 'Create')
    $archive = New-Object System.IO.Compression.ZipArchive($stream, 'Create')
    try {
        foreach ($pair in @(
            @{ Name = 'classes.dex'; Path = $newDex },
            @{ Name = 'META-INF/MANIFEST.MF'; Path = (Join-Path $origDir 'META-INF\MANIFEST.MF') }
        )) {
            $entry = $archive.CreateEntry($pair.Name)
            $es = $entry.Open()
            $bytes = [System.IO.File]::ReadAllBytes($pair.Path)
            $es.Write($bytes, 0, $bytes.Length)
            $es.Close()
        }
    }
    finally {
        $archive.Dispose()
        $stream.Close()
    }

    Write-Host "patched: $outFull"
}
finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
