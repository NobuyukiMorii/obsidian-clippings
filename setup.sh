#!/bin/bash
# ============================================================================
#  setup.sh（セットアップスクリプト）
#
#  このスクリプトの役割:
#    config.sh の設定値をもとに launchd の plist ファイルを自動生成し、
#    macOS に登録する。
#
#  やっていること:
#    1. config.sh を読み込む
#    2. plist ファイル（macOSの自動実行設定）を生成する
#    3. ~/Library/LaunchAgents/ に配置する
#    4. launchctl で macOS に登録する
#
#  使い方:
#    ./setup.sh          ← 初回セットアップ、または設定変更後に再実行
#    ./setup.sh uninstall ← 登録解除（自動実行を止める）
# ============================================================================

set -euo pipefail

# このスクリプトが存在するディレクトリの絶対パス（相対パスでの実行にも対応）
# 例: どこにいても `./setup.sh` や `obsidian-clippings/setup.sh` で起動したとき、
#     SCRIPT_DIR は常に setup.sh があるフォルダ（例: /Users/you/.../obsidian-clippings）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# プロジェクト直下の設定ファイル
CONFIG_FILE="$SCRIPT_DIR/config.sh"
# launchd の Label 用。ユーザー名を入れて他ユーザー・他ジョブと被らないようにする
PLIST_NAME="com.$(whoami).obsidian-clippings"
# 生成する LaunchAgent plist のパス
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"


# ============================================================================
#  アンインストール（引数に "uninstall" を指定した場合）
# ============================================================================

if [ "${1:-}" = "uninstall" ]; then
    echo "Uninstalling..."

    if launchctl list | grep -q "$PLIST_NAME"; then
        launchctl unload "$PLIST_DEST" 2>/dev/null || true
        echo "  launchd から登録解除しました"
    fi

    if [ -f "$PLIST_DEST" ]; then
        rm "$PLIST_DEST"
        echo "  plist ファイルを削除しました"
    fi

    echo "Done. 自動実行を停止しました。"
    exit 0
fi


# ============================================================================
#  config.sh の存在チェック
# ============================================================================

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: config.sh が見つかりません。"
    echo ""
    echo "  以下のコマンドでテンプレートからコピーしてください:"
    echo "  cp $SCRIPT_DIR/config.example.sh $SCRIPT_DIR/config.sh"
    echo ""
    echo "  コピー後、config.sh を自分の環境に合わせて編集してください。"
    exit 1
fi

source "$CONFIG_FILE"


# ============================================================================
#  デフォルト値の設定（process-clippings.sh と同じ）
# ============================================================================

CLIPPINGS_DIR="${CLIPPINGS_DIR:-$OBSIDIAN_DIR/Clippings}"
CLAUDE_PATH="${CLAUDE_PATH:-$(which claude 2>/dev/null || echo "")}"
LOGFILE="${LOGFILE:-$HOME/Library/Logs/obsidian-clippings.log}"


# ============================================================================
#  設定値のチェック
# ============================================================================

errors=0

if [ -z "${OBSIDIAN_DIR:-}" ]; then
    echo "ERROR: config.sh に OBSIDIAN_DIR が設定されていません。"
    errors=1
fi

if [ ! -d "$CLIPPINGS_DIR" ]; then
    echo "ERROR: Clippings フォルダが見つかりません: $CLIPPINGS_DIR"
    errors=1
fi

if [ -z "$CLAUDE_PATH" ]; then
    echo "ERROR: Claude CLI が見つかりません。"
    echo "  config.sh に CLAUDE_PATH を設定するか、Claude Code CLI をインストールしてください。"
    errors=1
fi

if [ $errors -eq 1 ]; then
    echo ""
    echo "config.sh の設定を確認してください。"
    exit 1
fi


# ============================================================================
#  既存の登録があれば解除する（再セットアップ時のため）
# ============================================================================

if launchctl list 2>/dev/null | grep -q "$PLIST_NAME"; then
    echo "既存の登録を解除しています..."
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi


# ============================================================================
#  ログフォルダの作成
# ============================================================================

LOG_DIR=$(dirname "$LOGFILE")
mkdir -p "$LOG_DIR"


# ============================================================================
#  ラッパーアプリの作成
#  iCloud フォルダへのアクセスにはフルディスクアクセス（FDA）が必要。
#  FDA は .app 形式でないと登録できないため、スクリプトを実行するだけの
#  最小限のアプリを作成する。
# ============================================================================

WRAPPER_APP="$HOME/Applications/ObsidianClippings.app"
WRAPPER_BIN="$WRAPPER_APP/Contents/MacOS/applet"

echo "ラッパーアプリを作成しています..."
mkdir -p "$HOME/Applications"
osacompile -o "$WRAPPER_APP" \
    -e "do shell script \"$SCRIPT_DIR/process-clippings.sh\"" 2>/dev/null
echo "  作成先: $WRAPPER_APP"


# ============================================================================
#  plist ファイルの生成
#  config.sh の値をもとに、macOS の自動実行設定ファイルを組み立てる。
# ============================================================================

echo "plist ファイルを生成しています..."

cat > "$PLIST_DEST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$WRAPPER_BIN</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>$CLIPPINGS_DIR</string>
    </array>
    <key>StandardOutPath</key>
    <string>$LOGFILE</string>
    <key>StandardErrorPath</key>
    <string>${LOGFILE%.log}-error.log</string>
</dict>
</plist>
EOF

echo "  作成先: $PLIST_DEST"


# ============================================================================
#  launchd に登録する
# ============================================================================

echo "launchd に登録しています..."
launchctl load "$PLIST_DEST"

echo ""
echo "========================================="
echo "  セットアップ完了!"
echo "========================================="
echo ""
echo "  Clippings フォルダを監視中:"
echo "    $CLIPPINGS_DIR"
echo ""
echo "  ログの確認:"
echo "    tail -f $LOGFILE"
echo ""
echo "  停止するには:"
echo "    ./setup.sh uninstall"
echo ""
echo "  ⚠ iCloud Drive 上の Vault を使っている場合:"
echo "    ObsidianClippings アプリにフルディスクアクセスを付与してください。"
echo "    詳しくは README.md の「フルディスクアクセスの設定」を参照。"
echo ""
