#!/bin/sh

# 除外するディレクトリとファイルパターン（空白区切り）
EXCLUDE_DIRS=".git .DS_Store"
EXCLUDE_FILES="go.sh out.txt"

# ディレクトリの -prune 条件を生成
PRUNE_ARGS=""
for d in $EXCLUDE_DIRS; do
  PRUNE_ARGS="$PRUNE_ARGS -name '$d' -o"
done
PRUNE_ARGS="${PRUNE_ARGS% -o}"  # 末尾の -o を削除

# ファイルの除外条件を生成
FILE_EXCLUDES=""
for f in $EXCLUDE_FILES; do
  FILE_EXCLUDES="$FILE_EXCLUDES ! -name '$f'"
done

# find コマンド行を組み立て（カッコはエスケープ必須）
if [ -n "$PRUNE_ARGS" ]; then
  FIND_LINE="find . \\( $PRUNE_ARGS \\) -prune -o \\( -type f $FILE_EXCLUDES \\) -print"
else
  FIND_LINE="find . \\( -type f $FILE_EXCLUDES \\) -print"
fi

# 実行：ファイル名 → 中身 を連続表示
# （パスに空白があっても壊れないように read -r / IFS=）
eval "$FIND_LINE" | while IFS= read -r file; do
  echo "===== $file ====="
  cat "$file"
  echo
done

