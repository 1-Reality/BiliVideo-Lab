Required Notice: Copyright © 2026 哥哥科技 (BroTech)<br>
Required Notice: https://github.com/ucxn/Bro-Stat · https://github.com/ucxn/ZTE-Stat_Max

# 哥哥科技脚本在 PiliBro 中的收录声明

本目录（`BroTech/`）及其下各子目录中的路由器增强脚本（本声明中亦称“插件”“组件”，三者所指相同），是哥哥科技独立创作、独立发布的作品。它们以原样收录的方式随 PiliBro 一同分发，彼此之间属于《GNU Affero 通用公共许可证》第三版第 5 条所称的“聚合”，而非由二者合成的单一作品。

**一、许可证互不延伸。** PiliBro 的 AGPLv3 不适用于本目录中的任何脚本；脚本的授权也不延伸到 PiliBro。每个脚本只受其自身头部 `@license`、`@copyright` 声明，以及所在子目录中许可证文件的约束。收录这一事实本身，不构成哥哥科技以 AGPLv3 或任何其他许可证重新发布这些脚本的意思表示，也不能据此推定存在这样的授权。

**二、分界线。** PiliBro 中负责读取、匹配、注入脚本以及实现 `GM_getValue`、`GM_setValue` 等接口的代码，属于 PiliBro 本身，按 AGPLv3 授权。脚本与 PiliBro 之间只通过油猴脚本的通用接口交互；同一脚本无需任何修改即可在其他脚本管理器中运行。

**三、不授予任何许可。** 本声明仅说明边界，不授予任何权利。对该组件的一切使用，包括随 PiliBro 或其衍生版本一并分发，均只依插件自身的许可证判断。PiliBro 的衍生版本可以整体删除脚本文件 和/或 本目录，这不影响其依据 AGPLv3 享有的任何权利。

**四、免责。** 脚本按原样提供，不附带任何明示或默示的担保。哥哥科技与 PiliBro 均不对脚本在任何设备、网页或路由器上的运行结果承担责任。

**五、冲突处理。** 本声明与脚本自身许可证不一致时，以脚本自身许可证为准。本声明各语言版本不一致时，以中文版本为准。

---

# About the 哥哥科技 Scripts Bundled with PiliBro

Everything under `BroTech/` is router tooling written and published by 哥哥科技 as its own work. This notice calls it a script, a plug-in or a component interchangeably; all three mean the same files. PiliBro carries these scripts the way a Linux distribution carries a firmware blob: side by side, untouched, and legally separate. In the vocabulary of the GNU Affero General Public License v3, this is an *aggregate* under Section 5, and Section 5 says plainly that putting a covered work into an aggregate does not make the license reach the other parts.

So the AGPL stops at PiliBro's edge. What PiliBro owns is the machinery: the code that finds these files, matches them against page addresses, injects them, and answers their `GM_getValue` and `GM_setValue` calls. That machinery is AGPLv3. The scripts on the other side of that line remain under whatever their own `@license` header and the license files in their subfolder say, and only that. The scripts talk to PiliBro through the same userscript interface every script manager offers, which is why each of them also runs unchanged in Violentmonkey or Via.

Shipping a script inside an AGPL application is not a relicensing. Nobody should read the presence of these files here as 哥哥科技 offering them under the AGPL, or under any terms other than their own.

This notice marks a boundary and nothing more. It grants no rights of any kind. Every use of this component, including shipping it inside PiliBro or a fork of it, is judged by the plug-in's own license alone. A fork may delete the script files and/or this folder; that costs it nothing under the AGPL.

Wherever these scripts travel, the attribution travels with them: "哥哥科技" stays in the source and in the user interface, untrimmed and unobscured, and this notice stays beside them.

If this notice and a script's own license ever disagree, the script's license wins. If the language versions of this notice disagree, the Chinese text governs.

---

# PiliBro に同梱される哥哥科技スクリプトについて

このフォルダ（`BroTech/`）とその配下にあるルーター向けスクリプト（本声明では「プラグイン」「コンポーネント」とも呼び、いずれも同じものを指します）は、哥哥科技が独自に作成・公開している著作物です。PiliBro には手を加えずにそのまま同梱しており、AGPL v3 第 5 条でいう「集合物（aggregate）」にあたります。両者が一つの著作物として結合しているわけではありません。

そのため、PiliBro の AGPL v3 はこれらのスクリプトには及びません。各スクリプトに適用されるのは、ファイル冒頭の `@license`・`@copyright` の記載と、同じサブフォルダ内のライセンスファイルだけです。PiliBro に収録されていることをもって、哥哥科技が AGPL v3 などで再許諾したと解釈することはできません。

スクリプトの読み込み・URL 照合・注入、そして `GM_getValue` や `GM_setValue` を提供するコードは PiliBro 側のものであり、こちらは AGPL v3 で提供されます。スクリプトとはユーザースクリプト共通のインターフェースでやり取りするだけなので、同じスクリプトは他のスクリプトマネージャーでもそのまま動作します。

本声明は境界を示すものにすぎず、いかなる権利も許諾しません。PiliBro やその派生版への同梱を含め、本コンポーネントの利用はすべてプラグイン自身のライセンスのみによって判断されます。派生版がスクリプトファイルおよび／またはこのフォルダを削除することは自由で、AGPL v3 上の権利には影響しません。

どの形で配布する場合でも、ソースコードとユーザーインターフェース中の「哥哥科技」という表記を削除・隠蔽・改変してはならず、この声明も削除できません。

本声明と各スクリプトのライセンスが食い違う場合は、スクリプトのライセンスが優先します。言語版の間で食い違いがある場合は、中国語版を正とします。
