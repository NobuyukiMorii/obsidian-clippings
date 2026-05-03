#!/bin/bash
# ============================================================================
#  config.sh（設定ファイル）
#
#  このファイルの使い方:
#    1. このファイルをコピーして「config.sh」という名前にする
#       cp config.example.sh config.sh
#    2. OBSIDIAN_DIR を自分の環境に合わせて書き換える
#    3. config.sh は .gitignore で除外されるので、GitHubには公開されない
# ============================================================================


# ----------------------------------------------------------------------------
#  必須設定
# ----------------------------------------------------------------------------

# Obsidian Vault のルートフォルダのパス
OBSIDIAN_DIR="/Users/あなたのユーザー名/path/to/your/obsidian/vault"

# 保存先フォルダは prompt.md で指定する（config.sh には不要）


# ----------------------------------------------------------------------------
#  以下はオプション（変更したい場合だけ書き換える）
#  書かなければスクリプトがデフォルト値を使う
# ----------------------------------------------------------------------------

# Clippings フォルダのパス（デフォルト: $OBSIDIAN_DIR/Clippings）
# CLIPPINGS_DIR="$OBSIDIAN_DIR/Clippings"

# Claude CLI のパス（デフォルト: 自動検出）
# CLAUDE_PATH="/Users/あなたのユーザー名/.local/bin/claude"

# ログファイルのパス（デフォルト: ~/Library/Logs/obsidian-clippings.log）
# LOGFILE="$HOME/Library/Logs/obsidian-clippings.log"

# Claude のモデル（デフォルト: sonnet）
# 選択肢: haiku, sonnet, opus
# CLAUDE_MODEL="sonnet"

