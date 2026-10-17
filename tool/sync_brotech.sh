#!/usr/bin/env bash
# Release builds only: refresh assets/BroTech/{ZTE,Mi,general} from the
# upstream script repositories. Files in assets/BroTech/ itself are not touched.
set -euo pipefail
cd "$(dirname "$0")/../assets/BroTech"

while read -r repo src dest; do
  curl -fsSL --retry 3 -o "$dest" "https://raw.githubusercontent.com/$repo/main/$src"
done <<'EOF'
ucxn/ZTE-Stat_Max .github/SECURITY.md ZTE/SECURITY.md
ucxn/ZTE-Stat_Max assets/nc_custom_noversion.svg ZTE/nc_custom_noversion.svg
ucxn/ZTE-Stat_Max README.md ZTE/README.md
ucxn/ZTE-Stat_Max README_EN.md ZTE/README_EN.md
ucxn/ZTE-Stat_Max LICENSE.markdown ZTE/LICENSE.markdown
ucxn/ZTE-Stat_Max LICENSE/SUL-1.0.md ZTE/LICENSE/SUL-1.0.md
ucxn/ZTE-Stat_Max LICENSE/suppfile.txt ZTE/LICENSE/suppfile.txt
ucxn/ZTE-Stat_Max LICENSE/license.txt ZTE/LICENSE/license.txt
ucxn/ZTE-Stat_Max LICENSE/BR-BY-NC-1.0.md ZTE/LICENSE/BR-BY-NC-1.0.md
ucxn/ZTE-Stat_Max LICENSE/CopyRight.md ZTE/LICENSE/CopyRight.md
ucxn/Mi-Stat_Max .github/SECURITY.md Mi/SECURITY.md
ucxn/Mi-Stat_Max .github/%E5%93%A5%E5%93%A5%E8%BD%AF%E4%BB%B6.svg Mi/哥哥软件.svg
ucxn/Mi-Stat_Max README.md Mi/README.md
ucxn/Mi-Stat_Max README_zh-Hans.md Mi/README_zh-Hans.md
ucxn/Mi-Stat_Max LICENSE.md Mi/LICENSE.md
ucxn/Bro-Stat README.md general/README.md
ucxn/Bro-Stat README_en.md general/README_en.md
ucxn/Bro-Stat License.md general/License.md
ucxn/Bro-Stat Copyright.md general/Copyright.md
ucxn/Bro-Stat .github/Install.md general/Install.md
ucxn/Bro-Stat LICENSE/README.MD general/COPYING/README.MD
ucxn/Bro-Stat Source/License/CPAL-1.0.md general/COPYING/License/CPAL-1.0.md
ucxn/Bro-Stat Source/License/DOSA-1.0.md general/COPYING/License/DOSA-1.0.md
ucxn/Bro-Stat Source/License/README.MD general/COPYING/License/README.MD
EOF
