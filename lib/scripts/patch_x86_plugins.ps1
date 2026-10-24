# 32 位 Windows 构建的插件补丁。只在 x86 工作流里、只改 CI 工作区与插件缓存里的副本，不提交。
# 调用时机：flutter build windows（生成 windows/flutter/ephemeral 与插件符号链接）之后，cmake 配置之前。
param(
    [string]$Root = (Get-Location).Path
)
$ErrorActionPreference = 'Stop'

# 1) 去掉 apply_standard_settings 里的 /WX（windows/CMakeLists.txt）。
#    32 位下 media_kit_video 等插件有窄化转换的警告（例如 media_kit_video/windows/video_output.cc:338），
#    /WX 会把它变成错误（C2220）。只影响这个 x86 构建。
$cm = Join-Path $Root 'windows\CMakeLists.txt'
$text = [IO.File]::ReadAllText($cm)
$patched = [regex]::Replace($text, ' /WX(?=\s|\))', '')
if ($patched -ne $text) {
    [IO.File]::WriteAllText($cm, $patched, [Text.UTF8Encoding]::new($false))
    Write-Host "removed /WX from $cm"
} else {
    Write-Host "no /WX found in $cm (already patched or changed upstream)"
}

# 2) jni 1.0.3：third_party/jni.h 里 JNI_OnLoad/JNI_OnUnload 的声明只有 JNIEXPORT，没有 JNICALL。
#    x86 上 JNICALL 是 __stdcall，src/dartjni.c 的定义带 JNICALL，两者不一致，报 C2373。
#    通过插件符号链接改的是 pub 缓存里的文件。
$jniHeader = Join-Path $Root 'windows\flutter\ephemeral\.plugin_symlinks\jni\third_party\jni.h'
if (Test-Path $jniHeader) {
    $h = [IO.File]::ReadAllText($jniHeader)
    $h2 = [regex]::Replace($h, 'JNIEXPORT (jint|void) (JNI_OnLoad|JNI_OnUnload)\(', 'JNIEXPORT $1 JNICALL $2(')
    if ($h2 -ne $h) {
        [IO.File]::WriteAllText($jniHeader, $h2, [Text.UTF8Encoding]::new($false))
        Write-Host "patched JNICALL in $jniHeader"
    } else {
        Write-Host "jni.h already has JNICALL or has a different shape: $jniHeader"
    }
} else {
    Write-Host "jni plugin header not found; skipping: $jniHeader"
}

# 3) jni 1.0.3 的原生库 dartjni.dll 在 Windows x86 上链接不上：find_package(JNI) 在 runner 上只找到 x64 JDK 的 jvm.lib。
#    应用里 jni 只用于 Android（lib/utils/font_utils.dart 的 _initAndroid；Windows 走 _initWindows，不调用 jni；
#    lib/utils/android/* 也是 Android 专用），所以这个 x86 构建里跳过 src 子目录的编译。
#    jni 的 windows/CMakeLists.txt 本身有 `if (TARGET jni) ... else ...` 分支，跳过后走 else，bundled 库为空。
$jniCm = Join-Path $Root 'windows\flutter\ephemeral\.plugin_symlinks\jni\windows\CMakeLists.txt'
if (Test-Path $jniCm) {
    $c = [IO.File]::ReadAllText($jniCm)
    $c2 = [regex]::Replace($c, '(?m)^add_subdirectory\("\$\{CMAKE_CURRENT_SOURCE_DIR\}/\.\./src".*\)\s*$', '# skipped for Windows x86 build (no 32-bit JDK jvm.lib); Windows does not call jni')
    if ($c2 -ne $c) {
        [IO.File]::WriteAllText($jniCm, $c2, [Text.UTF8Encoding]::new($false))
        Write-Host "skipped jni native library build in $jniCm"
    } else {
        Write-Host "jni add_subdirectory line not found (already patched or changed): $jniCm"
    }
} else {
    Write-Host "jni plugin CMake not found; skipping: $jniCm"
}
