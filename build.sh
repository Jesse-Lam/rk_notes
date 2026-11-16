#!/bin/bash
#
# build.sh —— 扫描仓库中的 Markdown 笔记，按目录生成根目录 README.md 索引
#
# 用法:
#   ./build.sh              # 生成 README.md
#   ./build.sh --check      # 只打印将要写入的内容，不修改 README.md
#
# 规则:
#   * 笔记 = 任意层级目录下的 *.md 文件
#   * 标题 = 文档中第一个一级标题(# )；没有一级标题时回退为文件名
#   * README.md 视为目录说明文档，标题取上级目录名
#   * .git、.assets、隐藏目录自动跳过
#
# 可选:
#   在根目录放置 README_HEADER.md，其内容会原样作为 README 的开头（标题、简介等），
#   脚本只负责在其后追加笔记索引。该文件不会被当作笔记收录。
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
README_FILE="$ROOT_DIR/README.md"
HEADER_FILE="$ROOT_DIR/README_HEADER.md"

DEFAULT_TITLE="RK平台开发笔记"
DEFAULT_INTRO="RK 平台（Rockchip）开发笔记，按目录分类，点击标题查看笔记。"

DRY_RUN=0
[ "${1:-}" = "--check" ] && DRY_RUN=1

# ---------- 工具函数 ----------

# 对路径做最小化转义：只编码会破坏 Markdown 链接语法的字符，保留 UTF-8 中文
url_encode() {
	printf '%s' "$1" | sed \
		-e 's/%/%25/g' \
		-e 's/(/%28/g' \
		-e 's/)/%29/g' \
		-e 's/ /%20/g' \
		-e 's/#/%23/g' \
		-e 's/?/%3F/g' \
		-e 's/\[/%5B/g' \
		-e 's/\]/%5D/g'
}

# 取 Markdown 文件中的第一个一级标题：跳过 YAML frontmatter 与围栏代码块
# 没有一级标题时输出空，由调用方回退为文件名
first_h1() {
	awk '
		NR == 1 && $0 ~ /^---[[:space:]]*$/ { fm = 1; next }
		fm == 1 { if ($0 ~ /^---[[:space:]]*$/) fm = 0; next }
		{
			# 围栏代码块内的 # 注释不是标题
			if ($0 ~ /^[[:space:]]*(```|~~~)/) { code = !code; next }
			if (!code && $0 ~ /^#[[:space:]]+[^#[:space:]]/) {
				line = $0
				sub(/^#[[:space:]]+/, "", line)
				sub(/[[:space:]]+#*[[:space:]]*$/, "", line)
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
				print line
				exit
			}
		}
	' "$1"
}

# 输出一个笔记条目
emit_note() {
	local file="$1" rel="$2" name title
	name="$(basename "$file")"

	if [ "$name" = "README.md" ]; then
		# 目录说明文档：标题取上级目录名
		title="$(basename "$(dirname "$rel")")"
	else
		title="$(first_h1 "$file")"
		if [ -z "$title" ]; then
			title="${name%.md}"
		fi
	fi

	printf '* [%s](%s)\n' "$title" "$(url_encode "$rel")"
}

# ---------- 读取页面标题 ----------

TITLE="$DEFAULT_TITLE"
INTRO="$DEFAULT_INTRO"

if [ -f "$README_FILE" ]; then
	existing_title="$(first_h1 "$README_FILE")"
	if [ -n "$existing_title" ]; then
		TITLE="$existing_title"
	fi
fi

# ---------- 收集目录与笔记 ----------

dirs=()
while IFS= read -r d; do
	[ -n "$d" ] && dirs+=("$d")
done < <(
	find "$ROOT_DIR" -mindepth 1 -type d \
		-not -path "$ROOT_DIR/.git" \
		-not -path "*/.git/*" \
		-not -path '*/.*' \
		| sed "s|^${ROOT_DIR}/||" \
		| LC_ALL=C sort
)

# ---------- 生成内容 ----------

gen() {
	local dir file rel notes

	# 头部：优先使用 README_HEADER.md，其次沿用现有 README 的一级标题
	if [ -f "$HEADER_FILE" ]; then
		cat "$HEADER_FILE"
		printf '\n'
	else
		printf '# %s\n\n%s\n\n' "$TITLE" "$INTRO"
	fi

	for dir in "${dirs[@]}"; do
		# 该目录下的笔记（仅本层，子目录会单独成节）
		notes=()
		while IFS= read -r f; do
			[ -n "$f" ] && notes+=("$f")
		done < <(
			find "$ROOT_DIR/$dir" -maxdepth 1 -type f -name '*.md' \
				-not -path '*/.*' \
				| LC_ALL=C sort
		)

		[ ${#notes[@]} -eq 0 ] && continue

		printf '## %s\n\n' "$(url_encode "$dir")"
		for file in "${notes[@]}"; do
			emit_note "$file" "$dir/$(basename "$file")"
		done
		printf '\n'
	done

	# 根目录下的笔记
	notes=()
	while IFS= read -r f; do
		[ -n "$f" ] && notes+=("$f")
	done < <(
		find "$ROOT_DIR" -maxdepth 1 -type f -name '*.md' \
		-not -name 'README.md' \
		-not -name 'README_HEADER.md' \
		-not -path '*/.*' \
		| LC_ALL=C sort
	)

	if [ ${#notes[@]} -gt 0 ]; then
		printf '## 根目录\n\n'
		for file in "${notes[@]}"; do
			emit_note "$file" "$(basename "$file")"
		done
		printf '\n'
	fi

	printf '<!-- 本文件由 build.sh 自动生成，请勿手动编辑 -->\n'
}

if [ "$DRY_RUN" -eq 1 ]; then
	gen
	exit 0
fi

tmp_file="$(mktemp "${README_FILE}.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT
gen >"$tmp_file"
mv "$tmp_file" "$README_FILE"
trap - EXIT

count="$(grep -c '^\* \[' "$README_FILE" || true)"
printf 'README.md 已更新，共索引 %s 篇笔记。\n' "$count"
