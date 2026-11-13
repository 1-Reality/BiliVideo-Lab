#!/usr/bin/env bash
# Release builds only: refresh assets/BroTech/{ZTE,Mi,general} from the
# upstream script repositories. Files in assets/BroTech/ itself are not touched.
set -euo pipefail
cd "$(dirname "$0")/../assets/BroTech"

while read -r repo src dest; do
  # Windows 的 Git Bash 把参数交给原生 curl 时按系统 ANSI 代码页转码，中文变成 ?，
  # curl 再把 ? 换成 _；改由 bash 自己重定向写文件，文件名不经过转码
  curl -fsSL --retry 3 "https://raw.githubusercontent.com/$repo/HEAD/$src" >"$dest"
done <<'EOF'
ucxn/ZTE-Stat_Max .github/SECURITY.md ZTE/SECURITY.md
ucxn/ZTE-Stat_Max assets/nc_custom_noversion.svg ZTE/nc_custom_noversion.svg
ucxn/ZTE-Stat_Max README.md ZTE/README.md
ucxn/ZTE-Stat_Max README_EN.md ZTE/README_EN.md
ucxn/ZTE-Stat_Max LICENSE.markdown ZTE/LICENSE.markdown
ucxn/ZTE-Stat_Max LICENSE/SUL-1.0.md ZTE/LICENSE/SUL-1.0.md
ucxn/ZTE-Stat_Max LICENSE/suppfile.txt ZTE/LICENSE/名字信息.txt
ucxn/ZTE-Stat_Max LICENSE/license.txt ZTE/LICENSE/哥哥科技通用许可证.txt
ucxn/ZTE-Stat_Max LICENSE/BR-BY-NC-1.0.md ZTE/LICENSE/显著署名半商业许可证.md
ucxn/ZTE-Stat_Max LICENSE/CopyRight.md ZTE/LICENSE/版权说明.md
ucxn/Mi-Stat_Max .github/SECURITY.md Mi/SECURITY.md
ucxn/Mi-Stat_Max .github/%E5%93%A5%E5%93%A5%E8%BD%AF%E4%BB%B6.svg Mi/哥哥软件.svg
ucxn/Mi-Stat_Max README.md Mi/README.md
ucxn/Mi-Stat_Max README_zh-Hans.md Mi/README_zh-Hans.md
ucxn/Mi-Stat_Max LICENSE.md Mi/LICENSE.md
ucxn/Bro-Stat README.md general/README.md
ucxn/Bro-Stat README_en.md general/README_en.md
ucxn/Bro-Stat License.md general/主许可证.md
ucxn/Bro-Stat Copyright.md general/版权声明.md
ucxn/Bro-Stat .github/Install.md general/安装.md
ucxn/Bro-Stat LICENSE/README.MD general/COPYING/README.MD
ucxn/Bro-Stat Source/License/CPAL-1.0.md general/COPYING/License/CPAL-1.0.md
ucxn/Bro-Stat Source/License/DOSA-1.0.md general/COPYING/License/DOSA-1.0.md
ucxn/Bro-Stat Source/License/README.MD general/COPYING/License/README.MD
ucxn/BroTech LICENSE 哥哥科技/LICENSE
ucxn/BroTech README.md 哥哥科技/README.md
ucxn/BroTech README_EN.md 哥哥科技/README_EN.md
ucxn/BroTech %E5%85%84%E5%BC%9F%E5%85%B3%E7%B3%BB%E4%BF%83%E8%BF%9B%E6%B3%95.md 哥哥科技/兄弟关系促进法.md
ucxn/RSA-message-encrypt AGENTS.md RSA/AGENTS.md
ucxn/RSA-message-encrypt CLAUDE.md RSA/CLAUDE.md
ucxn/RSA-message-encrypt LICENSE.md RSA/LICENSE.md
ucxn/RSA-message-encrypt LICENSE_en.md RSA/LICENSE_en.md
ucxn/RSA-message-encrypt LICENSE_ja.md RSA/LICENSE_ja.md
ucxn/RSA-message-encrypt LICENSE_zh-Hans-cmn-Hankow.md RSA/LICENSE_zh-Hans-cmn-Hankow.md
ucxn/RSA-message-encrypt README.md RSA/README.md
ucxn/RSA-message-encrypt %E8%AF%B4%E6%98%8E.go RSA/说明.go
ucxn/RSA-message-encrypt %E8%AE%A8%E6%9F%90%E6%95%99%E6%9D%A1AI%E6%AA%84%E6%96%87.md RSA/讨某教条AI檄文.md
ucxn/NAT-Checker LICENSE.md NAT/LICENSE.md
ucxn/NAT-Checker README.md NAT/README.md
ucxn/NAT-Checker main.go NAT/main.go
ucxn/NAT-Checker %E6%AD%A3%E5%AE%97NAT2%E6%B0%91%E9%97%B4%E7%BB%9F%E8%AE%A1.png NAT/正宗NAT2民间统计.png
EOF