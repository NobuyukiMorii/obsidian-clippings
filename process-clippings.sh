#!/bin/bash
# process-clippings.sh
#
# Obsidian の Clippings フォルダに追加された新着 .md を、
# prompt.md の指示に従って Claude AI に処理させる。
# launchd から自動実行される（手動実行も可）。

set -euo pipefail  # エラーが起きたら即停止。未定義変数の参照もエラーにする。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"  # このスクリプト自身がある場所（config.sh などの基準パスになる）


# === 設定の読み込み ===========================================================

CONFIG_FILE="$SCRIPT_DIR/config.sh"
[ -f "$CONFIG_FILE" ] || {           # config.sh がなければ使い方を教えて終了
    echo "ERROR: config.sh が見つかりません。"
    echo "  cp $SCRIPT_DIR/config.example.sh $SCRIPT_DIR/config.sh"
    exit 1
}
source "$CONFIG_FILE"                # config.sh の内容を読み込む（変数が定義される）

# config.sh で指定がなかった項目はここで補う
CLIPPINGS_DIR="${CLIPPINGS_DIR:-$OBSIDIAN_DIR/Clippings}"             # 監視対象。新着記事が入るフォルダ
CLAUDE_PATH="${CLAUDE_PATH:-$(which claude 2>/dev/null || echo "")}"  # Claude CLI の実行ファイル（未指定なら $PATH から自動検出）
CLAUDE_MODEL="${CLAUDE_MODEL:-sonnet}"                                # 使う Claude のモデル名（sonnet / opus / haiku など）
LOGFILE="${LOGFILE:-$HOME/Library/Logs/obsidian-clippings.log}"       # 処理ログの出力先

# このスクリプト自身が使う固定パス
PROMPT_FILE="$SCRIPT_DIR/prompt.md"          # Claude に渡す指示文の置き場所
LAST_RUN_FILE="$SCRIPT_DIR/.last_run"        # 前回実行時刻の記録（これより新しいファイルだけ処理する）
LOCKFILE="/tmp/obsidian-clippings.lock"      # 二重起動を防ぐためのロックファイル

# 必須項目が揃っているか確認。足りなければエラーで終了。
[ -n "${OBSIDIAN_DIR:-}" ] || { echo "ERROR: config.sh に OBSIDIAN_DIR を設定してください"; exit 1; }
[ -n "$CLAUDE_PATH" ]      || { echo "ERROR: Claude CLI が見つかりません (config.sh の CLAUDE_PATH か、Claude Code CLI のインストールを確認)"; exit 1; }
[ -f "$PROMPT_FILE" ]      || { echo "ERROR: prompt.md が見つかりません: $PROMPT_FILE"; exit 1; }


# === 共通の道具（log・ロック・判定・Claude 呼び出し）=========================

# ログに1行追記する。呼び出すたびに日時が先頭に付く。
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOGFILE"
}

# -----------------------------
# 二重起動の防止
# -----------------------------
acquire_lock_or_exit() {
    if [ -f "$LOCKFILE" ]; then
        local pid
        pid=$(cat "$LOCKFILE" 2>/dev/null)          # ロックファイルに書かれたプロセスID を読む
        if kill -0 "$pid" 2>/dev/null; then         # そのプロセスがまだ生きていれば
            log "Already running (pid=$pid), skipping"
            exit 0                                  # 何もせず終了
        fi
    fi
    echo $$ > "$LOCKFILE"               # 自分のプロセスID をロックファイルに書く（$$ = 自分のPID）
    trap 'rm -f "$LOCKFILE"' EXIT       # スクリプト終了時に必ずロックファイルを消す
}

# -----------------------------
# 新着ファイルの判定
# -----------------------------
should_process() {
    local file="$1"
    local filename
    filename=$(basename "$file")                     # フルパスからファイル名だけ取り出す

    [[ "$filename" == .* ]]         && return 1      # .DS_Store などのドットファイルはスキップ
    [[ "$filename" == *".icloud" ]] && return 1      # iCloud が同期中に作る一時ファイルはスキップ

    if [ -f "$LAST_RUN_FILE" ] && [ ! "$file" -nt "$LAST_RUN_FILE" ]; then
        return 1  # 前回実行より古い（または同じ時刻）ファイルはスキップ（-nt = newer than）
    fi

    if echo "$PROCESSED_FILES" | grep -qF "$filename"; then
        return 1  # 今回のループで既に処理したファイルはスキップ
    fi

    return 0  # ここまで来たら処理対象
}

# -----------------------------
# Claudeで処理し、.mdの増減で判定。結果をログ。「0=成功, 1=失敗」
# -----------------------------
process_with_claude() {
    # この関数は「1つのファイルをClaudeに読ませて処理する」という一連の作業をまとめたもの。
    # 引数として受け取ったファイルパスを使い、Claudeを起動する。

    # 関数に渡された最初の引数（処理対象のファイルの場所）を $file という名前で受け取る
    local file="$1"

    # ファイルの「フルパス」からファイル名だけを取り出す変数を用意する
    # 例: /path/to/article.md → article.md
    local filename
    filename=$(basename "$file")

    # 今からClaudeにこのファイルを送ることをログに記録する
    log "Sending to Claude: $filename"

    # このファイルが最後に更新された日時を取得する変数を用意する
    local file_timestamp
    # stat コマンドでファイルの更新日時を「年月日時分秒」の数字14桁で取得する
    # 例: 20260503155900（2026年5月3日15時59分00秒）
    file_timestamp=$(stat -f '%Sm' -t '%Y%m%d%H%M%S' "$file")

    # Claudeへの指示文（プロンプト）を組み立てる変数を用意する
    local prompt
    # BASE_PROMPT・ファイルパス・タイムスタンプを一つの文字列にして prompt に入れる
    # （printf -v prompt "..." は、結果を変数に代入する書き方）
    printf -v prompt '%s\n\nSOURCE FILE: %s\nFILE_TIMESTAMP: %s' \
        "$BASE_PROMPT" "$file" "$file_timestamp"
    # 例: prompt の中身
    #   （prompt.md の内容）
    #
    #   SOURCE FILE: /Users/mory/obsidian/Clippings/some-article.md
    #   FILE_TIMESTAMP: 20260503155900


    # Claude を実行する。
    if ! "$CLAUDE_PATH" -p "$prompt" --model "$CLAUDE_MODEL" --dangerously-skip-permissions > /dev/null 2>>"$LOGFILE"; then
        log "ERROR: Claude exited with error: $filename"
        return 1
    fi

    log "Processed: $filename"
    return 0
}


# -----------------------------
# 本処理の開始
# -----------------------------

acquire_lock_or_exit                         # 二重起動でないことを確認してからスタート

BASE_PROMPT=$(cat "$PROMPT_FILE")            # prompt.md の内容を丸ごと変数に入れる
PROCESSED_FILES=""                           # 今回の実行で処理済みのファイル名を蓄積する変数
total_found=0                                # 今回の実行で処理したファイルの合計数

# Clippings へのファイル書き込みが落ち着くまで少し待つ
sleep 5
log "Checking for new clippings..."

# -----------------------------
# ファイル処理ループ 
# -----------------------------
# 処理中に新着ファイルが追加される場合があるため、新着ゼロになるまでスキャンを繰り返す。
while true; do

    # 今回のループで処理したファイル数を記録するカウンタ。
    round_found=0

    # CLIPPINGS_DIR 内の全 .md ファイルを1件ずつ確認する。
    for file in "$CLIPPINGS_DIR"/*.md; do

        # 対象ファイルが存在しない場合はスキップする。
        [ -f "$file" ] || continue

        # 新着ファイルかどうかを判定する
        should_process "$file" || continue

        # Claude にファイルを渡して処理する。
        if process_with_claude "$file"; then

            # 処理成功した場合はカウンタをインクリメントして、処理済みファイルリストに追加する。
            round_found=$((round_found + 1))

            # 処理済みファイルリストにファイル名を追加する。
            printf -v PROCESSED_FILES '%s\n%s' "$PROCESSED_FILES" "$(basename "$file")"

        fi
    done

    # 今回のループの処理件数を累計に加算する。
    total_found=$((total_found + round_found))

    # 今回のループのスキャンで処理対象ファイルが0件なら、新着なしが確定したとみなしてループを抜ける。
    [ $round_found -eq 0 ] && break

    # 1件以上処理できた場合は、その間に新しいファイルが追加されている
    # 可能性があるため、もう1周スキャンする。
    log "Rechecking for files added during processing..."
done


# -----------------------------
# 完了 
# -----------------------------

if [ $total_found -eq 0 ]; then
    log "No new articles to process"
else
    touch "$LAST_RUN_FILE"                  # 完了時刻を .last_run に記録（次回起動時の判定基準になる）
    log "Processed $total_found file(s)"
fi
