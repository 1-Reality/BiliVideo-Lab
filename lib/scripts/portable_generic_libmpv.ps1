param([Parameter(Mandatory)][string]$Dir)
$ErrorActionPreference = "Stop"

# 便携包的 libmpv 换成通用 x86_64 版：安装包用 x86-64-v3（需要 AVX2），便携包给不支持 AVX2 的电脑兜底。
# 与 v3 是同一期 Lab（My-Responsitories 20260911，mpv 41f6a64，带 DXGI 渲染接口），只是编译目标不同。来源与 MD5 见 deps_mirror.yml
$Name = "mpv-dev-x86_64-20260911-git-41f6a64.7z"
$Md5 = "e5be5d1fbc2a38ec98dd7fb9718a95da"
$Tmp = Join-Path $env:RUNNER_TEMP "mpv-generic"
$Archive = Join-Path $Tmp $Name

New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
Invoke-WebRequest "https://github.com/1-Reality/BiliVideo-Lab/releases/download/deps-mirror/$Name" -OutFile $Archive
if ((Get-FileHash $Archive -Algorithm MD5).Hash -ne $Md5) { throw "MD5 mismatch: $Name" }
7z e $Archive "-o$Tmp" libmpv-2.dll -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw "7z failed: $Name" }
Copy-Item (Join-Path $Tmp "libmpv-2.dll") $Dir -Force
Copy-Item "windows/packaging/portable/*.txt" $Dir