param([Parameter(Mandatory)][string]$Dir)
$ErrorActionPreference = "Stop"

# 便携包的 libmpv 换成通用 x86_64 版：安装包用 x86-64-v3（需要 AVX2），便携包给不支持 AVX2 的电脑兜底。
# 与 v3 是同一期 shinchiro 20261021（mpv e471496c56），只是编译目标不同。来源与 MD5 见 deps_mirror.yml
$Name = "mpv-dev-x86_64-20261021-git-e471496c56.7z"
$Md5 = "93a7a2a41d2c26def4084c0b289fc94b"
$Tmp = Join-Path $env:RUNNER_TEMP "mpv-generic"
$Archive = Join-Path $Tmp $Name

New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
Invoke-WebRequest "https://github.com/1-Reality/BiliVideo-Lab/releases/download/deps-mirror/$Name" -OutFile $Archive
if ((Get-FileHash $Archive -Algorithm MD5).Hash -ne $Md5) { throw "MD5 mismatch: $Name" }
7z e $Archive "-o$Tmp" libmpv-2.dll -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw "7z failed: $Name" }
Copy-Item (Join-Path $Tmp "libmpv-2.dll") $Dir -Force
Copy-Item "windows/packaging/portable/*.txt" $Dir