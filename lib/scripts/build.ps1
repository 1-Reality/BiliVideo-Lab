param(
    [string]$Arg = ''
)

try {
    $pubspecVersion = $null
    foreach ($line in (Get-Content -Path 'pubspec.yaml' -Encoding UTF8)) {
        if ($line -match '^\s*version:\s*([\d\.]+)') {
            $pubspecVersion = $matches[1]
            break
        }
    }

    if ($null -eq $pubspecVersion) {
        throw 'version not found in pubspec.yaml'
    }

    # Explicit workflow inputs passed through environment variables take priority.
    # Event payload and tag refs remain supported for direct workflow/local reuse.
    $releaseTag = [string]$env:RELEASE_TAG_OVERRIDE
    if ([string]::IsNullOrWhiteSpace($releaseTag) -and $env:GITHUB_EVENT_PATH -and (Test-Path $env:GITHUB_EVENT_PATH)) {
        try {
            $eventPayload = Get-Content -Raw -Path $env:GITHUB_EVENT_PATH -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $eventPayload.inputs -and $null -ne $eventPayload.inputs.tag) {
                $releaseTag = [string]$eventPayload.inputs.tag
            }
        }
        catch {
            $releaseTag = ''
        }
    }

    if ([string]::IsNullOrWhiteSpace($releaseTag) -and $env:GITHUB_REF_TYPE -eq 'tag') {
        $releaseTag = [string]$env:GITHUB_REF_NAME
    }

    $versionName = $pubspecVersion
    if (-not [string]::IsNullOrWhiteSpace($releaseTag)) {
        if ($releaseTag -match '(?<!\d)(\d+\.\d+\.\d+)(?!\d)') {
            $versionName = $matches[1]
        }
        else {
            throw "release tag '$releaseTag' does not contain a x.y.z version"
        }
    }

    $buildNumberOverride = [string]$env:BUILD_NUMBER_OVERRIDE
    if ([string]::IsNullOrWhiteSpace($buildNumberOverride) -and $env:GITHUB_EVENT_PATH -and (Test-Path $env:GITHUB_EVENT_PATH)) {
        try {
            $eventPayloadForBuild = Get-Content -Raw -Path $env:GITHUB_EVENT_PATH -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $eventPayloadForBuild.inputs -and $null -ne $eventPayloadForBuild.inputs.build_number) {
                $buildNumberOverride = [string]$eventPayloadForBuild.inputs.build_number
            }
        }
        catch {
            $buildNumberOverride = ''
        }
    }

    $commitCount = [int](git rev-list --count HEAD).Trim()
    $isAndroid = $Arg -ieq 'android'
    $artifactVersion = $null

    if ($isAndroid) {
        if ($commitCount -gt 9999) {
            throw "Android date+commit build number requires commit count <= 9999, got $commitCount"
        }
        $chinaNow = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8))
        $datePrefix = '{0:D2}{1:D3}' -f ($chinaNow.Year % 100), $chinaNow.DayOfYear
        $artifactVersion = "$versionName+$datePrefix$($chinaNow.ToString('HHmm'))"
    }

    if ([string]::IsNullOrWhiteSpace($buildNumberOverride) -or $buildNumberOverride -eq '0') {
        if ($isAndroid) {
            $versionCode = [int]("$datePrefix$($commitCount.ToString('D4'))")
            $buildNumberSource = 'date+commit'
        }
        else {
            $versionCode = $commitCount
            $buildNumberSource = 'auto'
        }
    }
    elseif ($buildNumberOverride -match '^[1-9][0-9]*$') {
        $versionCode = [int]$buildNumberOverride
        $buildNumberSource = 'manual'
    }
    else {
        throw "build number '$buildNumberOverride' must be 0 or a positive integer"
    }

    if (-not $isAndroid) {
        $artifactVersion = "$versionName+$versionCode"
    }

    $commitHash = (git rev-parse HEAD).Trim()

    Write-Host "Version name: $versionName"
    Write-Host "Build number: $versionCode ($buildNumberSource)"
    if ($isAndroid) {
        Write-Host "Android artifact version: $artifactVersion"
    }
    Write-Host "Full version: $versionName+$versionCode"

    $updatedContent = foreach ($line in (Get-Content -Path 'pubspec.yaml' -Encoding UTF8)) {
        if ($line -match '^\s*version:\s*[\d\.]+(?:\+\d+)?') {
            "version: $versionName+$versionCode"
        }
        else {
            $line
        }
    }
    $updatedContent | Set-Content -Path 'pubspec.yaml' -Encoding UTF8

    $buildTime = [int]([DateTimeOffset]::Now.ToUnixTimeSeconds())

    $data = @{
        'pili.name' = $versionName
        'pili.code' = $versionCode
        'pili.hash' = $commitHash
        'pili.time' = $buildTime
    }

    $data | ConvertTo-Json -Compress | Out-File 'pili_release.json' -Encoding UTF8

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_ENV)) {
        Add-Content -Path $env:GITHUB_ENV -Value "version=$versionName+$versionCode"
        Add-Content -Path $env:GITHUB_ENV -Value "artifact_version=$artifactVersion"
    }
}
catch {
    Write-Error "Prebuild Error: $($_.Exception.Message)"
    exit 1
}
