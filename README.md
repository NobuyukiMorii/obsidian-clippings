# obsidian-clippings

Obsidian の Clippings フォルダを監視して、新しい記事を Claude AI で自動処理するツール。

どの記事をどう変換してどこに保存するかは、すべて `prompt.md` で決まる。
例: 英語学習用の翻訳・単語リスト付きフォーマット、要約、構造化メモなど。

## どういう仕組み？

```
Clippings フォルダに記事を追加
        ↓
macOS が変更を検知（launchd）
        ↓
process-clippings.sh が自動で起動
        ↓
Claude AI が prompt.md の指示に従って判断・変換・保存
```

## ファイル構成

```
obsidian-clippings/
├── config.example.sh    ← 設定ファイルのテンプレート（これをコピーして使う）
├── config.sh            ← 自分用の設定ファイル（.gitignore で除外）
├── prompt.example.md    ← プロンプトのテンプレート（これをコピーして使う）
├── prompt.md            ← 自分用のプロンプト（.gitignore で除外）
├── process-clippings.sh ← メインのスクリプト
├── setup.sh             ← セットアップ用スクリプト
├── .gitignore           ← Git 管理から除外するファイルの一覧
└── README.md            ← このファイル
```

## 必要なもの

- macOS
- [Obsidian](https://obsidian.md/) + [Obsidian Web Clipper](https://obsidian.md/clipper)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) がインストール済みであること

## セットアップ手順

### 1. リポジトリをクローン

```bash
git clone https://github.com/NobuyukiMorii/obsidian-clippings.git
cd obsidian-clippings
```

### 2. テンプレートをコピー

```bash
cp config.example.sh config.sh
cp prompt.example.md prompt.md
```

### 3. config.sh を編集する

自分の環境に合わせてパスを書き換える：

**必須設定:**

- `OBSIDIAN_DIR` — Obsidian Vault のパス

**オプション設定（変更したい場合のみ）:**

- `CLIPPINGS_DIR` — Clippings フォルダのパス（デフォルト: `$OBSIDIAN_DIR/Clippings`）
- `CLAUDE_PATH` — Claude CLI のパス（デフォルト: `which claude` の結果）
- `LOGFILE` — ログファイルのパス（デフォルト: `~/Library/Logs/obsidian-clippings.log`）
- `CLAUDE_MODEL` — 使用するモデル（デフォルト: `sonnet`、選択肢: `haiku` / `sonnet` / `opus`）

### 4. prompt.md を編集する

**ここがこのツールの核心。** Claude AI への指示文を自分の用途に合わせて書く。

prompt.md に書く内容の例：
- どの記事を処理するか（URLやサイト名での振り分け）
- どのフォルダ・ファイル名で保存するか
- どう変換するか（要約、翻訳、単語リスト、構造化メモなど）
- その他 Claude に伝えたい任意の指示

テンプレート（`prompt.example.md`）に基本的な書き方の例がある。

### 5. セットアップを実行

```bash
chmod +x setup.sh process-clippings.sh
./setup.sh
```

### 6. フルディスクアクセスの設定

**Obsidian Vault が iCloud Drive 上にある場合のみ、この設定が必要。ローカルフォルダ（`~/Documents/ObsidianVault` など）を使っている場合はスキップして OK。**

macOS のプライバシー保護により、launchd から実行されるプログラムは iCloud フォルダ（`~/Library/Mobile Documents/`）にアクセスできない。この制限を解除するために、ラッパーアプリにフルディスクアクセスを付与する。

#### なぜアプリが必要か

macOS のフルディスクアクセスは `.app` 形式にしか付与できないため、スクリプトを呼び出す小さなラッパーアプリを経由して権限を取得する。

#### 設定手順

**1. setup.sh を再実行する：**

```bash
./setup.sh
```

これにより、フルディスクアクセス用のラッパーアプリ（権限取得のための小さな `.app`）の作成と、自動実行スケジュール（launchd の設定ファイル）の更新が一括で行われる。

**2. フルディスクアクセスを付与する：**

1. **システム設定** → **プライバシーとセキュリティ** → **フルディスクアクセス** を開く
2. **+** ボタンをクリック
3. **Cmd+Shift+G** を押して `~/Applications` と入力
4. **ObsidianClippings** を選択して「開く」
5. トグルをオンにする

#### 解除方法

フルディスクアクセスの設定画面で ObsidianClippings のトグルをオフにするか、リストから削除する。ラッパーアプリ自体を削除するには：

```bash
rm -rf ~/Applications/ObsidianClippings.app
```

## 処理の仕組み

- スクリプトは `.last_run` というタイムスタンプファイルを使って、前回の実行以降に追加されたファイルだけを処理する
- 処理済みのファイルは Clippings フォルダに残る（削除されない）
- 同じファイルが再処理されることはない
- 記事の処理中に新しいファイルが追加された場合も取りこぼさない。1ラウンドの処理が終わるたびに新しいファイルがないか再チェックし、なくなるまで繰り返す

## よく使うコマンド

### どこからでも実行できるようにする（オプション）

`~/.zshrc` にエイリアスを追加すると、どのディレクトリからでも実行できる：

```zsh
alias obc='/path/to/obsidian-clippings/process-clippings.sh'
```

追加後は `source ~/.zshrc` を実行するか、ターミナルを再起動する。

### 手動でスクリプトを実行する（テスト用）

```bash
./process-clippings.sh
```

### ログを確認する

```bash
# 処理ログを見る（パスは config.sh の LOGFILE で変更可能）
cat ~/Library/Logs/obsidian-clippings.log

# リアルタイムでログを監視する
tail -f ~/Library/Logs/obsidian-clippings.log
```

### 監視が動いているか確認する

```bash
launchctl list | grep obsidian-clippings
```

出力があれば動いている。なければ停止中。

### 自動実行を停止する

```bash
./setup.sh uninstall
```

### 設定を変更した後に再セットアップ

```bash
./setup.sh
```

## トラブルシューティング

### 記事が処理されない場合

1. ログを確認する（上のコマンド参照）
2. `prompt.md` の振り分けルールを確認する
3. ログに `Operation not permitted` が出ていたら「フルディスクアクセスの設定」を確認する

### Mac 再起動後に動かない場合

通常は自動で再開されるが、もし動かなければ：

```bash
./setup.sh
```
