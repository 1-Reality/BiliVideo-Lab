import 'dart:ffi';
import 'dart:io' show File, Platform;

import 'package:PiliBro/common/constants.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// 电脑位宽与视频流畅度诊断，只有 Windows 有。设置里手动打开；首次启动查出问题时自动弹一次
abstract final class PcCheck {
  // 与 64 位版自带内核同一个 mpv 提交，只是按通用 x86-64 编译
  static const _genericMpv =
      'https://github.com/1-Reality/BiliVideo-Lab/releases/download/deps-mirror/mpv-dev-x86_64-20261021-git-e471496c56.7z';

  static final _exe = DynamicLibrary.executable();

  static bool get _app32 => Abi.current() == Abi.windowsIA32;

  // 32 位程序跑在 64 位系统上时才有这个环境变量
  static bool get _os64 =>
      !_app32 || Platform.environment.containsKey('PROCESSOR_ARCHITEW6432');

  // 安装版目录里有 Inno Setup 的卸载程序；便携包没有，它自带的是通用版内核，不需要 AVX2
  static bool get _installed => File(
    '${File(Platform.resolvedExecutable).parent.path}\\unins000.exe',
  ).existsSync();

  static bool get _v3 =>
      _exe.lookupFunction<Int32 Function(), int Function()>('PcCheckV3')() != 0;

  static void onFirstLaunch() {
    if (_app32 ? _os64 : !_v3 && _installed) show();
  }

  static void show() {
    final app32 = _app32, os64 = _os64, v3 = _v3, installed = _installed;
    final gpu = _exe
        .lookupFunction<Pointer<Utf16> Function(), Pointer<Utf16> Function()>(
          'PcCheckGpu',
        )()
        .toDartString();
    SmartDialog.show(
      useSystem: true,
      animationType: SmartAnimationType.centerFade_otherSlide,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final head = theme.textTheme.titleSmall;
        final note = TextStyle(color: colorScheme.outline);
        Widget verdict(Color color, String text) =>
            Text(text, style: TextStyle(color: color));
        return AlertDialog(
          title: const Text('电脑位宽与视频流畅度诊断'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  '位宽：系统 ${os64 ? 64 : 32} 位，程序 ${app32 ? 32 : 64} 位',
                  style: head,
                ),
                if (!app32)
                  verdict(Colors.green, '完美，64 位系统跑 64 位版。')
                else if (!os64)
                  verdict(
                    Colors.orange,
                    '32 位系统只能用 32 位版，可以正常使用。32 位版的界面跑在 JIT 模式，启动和滑动比 64 位版慢一些。',
                  )
                else ...[
                  verdict(
                    colorScheme.error,
                    '装错版本了：系统是 64 位，用的却是 32 位版。32 位版的界面跑在 JIT 模式，启动和滑动都更慢。请到发布页下载 64 位版（rar 便携包或 exe 安装包），装好后把这个 32 位版的文件夹删掉就行。',
                  ),
                  TextButton(
                    onPressed: () => PageUtils.launchURL(
                      '${Constants.sourceCodeUrl}/releases/latest',
                    ),
                    child: const Text('打开发布页'),
                  ),
                ],
                if (os64) ...[
                  const Divider(),
                  Text('指令集：CPU ${v3 ? '' : '不'}支持 AVX2', style: head),
                  if (v3)
                    verdict(Colors.green, '64 位版自带的播放内核可以直接用。')
                  else if (app32)
                    verdict(
                      Colors.orange,
                      '64 位版请下 rar 便携包，它自带通用版内核，可以直接用；exe 安装包的内核需要 AVX2，装了要按下面的步骤换。',
                    )
                  else if (!installed)
                    verdict(Colors.green, '你用的是便携包，自带通用版内核，不需要 AVX2，可以直接用。')
                  else
                    verdict(
                      colorScheme.error,
                      '安装版自带的播放内核需要 AVX2，这台电脑播放视频会闪退。最省事的是改用 rar 便携包，它自带通用版内核；想继续用安装版，按下面的步骤换内核。已经换过的，忽略这条即可。',
                    ),
                  Text('安装版换成通用版内核（给不支持 AVX2 的电脑用）', style: head),
                  const Text(
                    '1. 点下面的按钮，下载通用版内核的压缩包（约 30 MB）。已经下过 rar 便携包的，它里面的 libmpv-2.dll 就是通用版，直接跳到第 3 步。\n'
                    '2. 用 7-Zip、Bandizip 或 WinRAR 解压（较新的 Windows 11 也可以直接右键「全部解压缩」），解压出来的文件里有一个 libmpv-2.dll。\n'
                    '3. 完全退出 PiliBro：关掉窗口后，右下角托盘里如果还有它的图标，右键选「退出 PiliBro」。\n'
                    '4. 在桌面上右键 PiliBro 的快捷方式，选「打开文件所在的位置」。桌面上没有快捷方式的，在开始菜单里右键 PiliBro，选「更多」→「打开文件位置」，再对打开的快捷方式做一次同样的操作。\n'
                    '5. 打开的文件夹里能看到 pilibro.exe 和 libmpv-2.dll。把第 2 步解压出来的 libmpv-2.dll 拖进这个文件夹，选「替换目标中的文件」；提示需要管理员权限，点「继续」。\n'
                    '6. 重新打开 PiliBro。以后每次更新都会装回自带的内核，再做一遍第 3 到 5 步就行，第 2 步解压出来的文件留着别删。',
                  ),
                  TextButton(
                    onPressed: () => PageUtils.launchURL(_genericMpv),
                    child: const Text('下载通用版内核'),
                  ),
                ],
                if (gpu.isNotEmpty) ...[
                  const Divider(),
                  Text('显卡：$gpu', style: head),
                  Text(
                    '有核显和独显两张卡的电脑，可以在 Windows 设置里搜索「图形设置」，给 PiliBro 指定用哪张。老一些的 Intel 核显解码视频不一定比独显差，播放卡顿时两张都试试。',
                    style: note,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: SmartDialog.dismiss,
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }
}