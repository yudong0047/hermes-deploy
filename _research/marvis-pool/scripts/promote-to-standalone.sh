#!/usr/bin/env bash
# 把本项目（当前以独立分支形式托管）转正为独立 GitHub 仓库。
# 用法：先在 GitHub 网页新建一个空的公开仓库 <YOUR_REPO>，然后：
#   git remote add standalone https://github.com/<you>/<YOUR_REPO>.git
#   bash scripts/promote-to-standalone.sh
set -euo pipefail

if ! git remote get-url standalone >/dev/null 2>&1; then
  echo "请先添加 remote: git remote add standalone https://github.com/<you>/<YOUR_REPO>.git" >&2
  exit 1
fi

# 本项目在 hermes-deploy 中以 orphan 分支承载；该分支的内容就是完整项目根目录。
git push standalone HEAD:main
echo "已推送到 standalone 的 main 分支。"
