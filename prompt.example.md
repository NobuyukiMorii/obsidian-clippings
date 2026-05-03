<!-- ================================================================
  prompt.example.md — プロンプトのテンプレート

  使い方:
    1. このファイルをコピーして「prompt.md」という名前にする
       cp prompt.example.md prompt.md
    2. prompt.md を自分の用途に合わせて書き換える

  何でも書いていい。Claude への自由形式の指示文。例えば:
    - URL・ドメイン・タイトルによる振り分けルール
    - 出力ファイル名のフォーマット
    - 要約・翻訳・単語リスト・構造化メモ・箇条書き
    - タグ付けや YAML frontmatter の加工
    - 宣伝フッターや不要コンテンツの削除　など
================================================================ -->

下記のパスにあるファイルを読み取る。

## 振り分けルール

YAML frontmatter の `title` を確認する。
タイトルが英語の場合、記事を変換して保存する。
それ以外は何もしない。

保存先: /path/to/your/vault/processed/english/

## 出力ファイル名

元ファイルパスの下に与えられる `FILE_TIMESTAMP`、ソース `source` の URL ドメイン、YAML frontmatter の `title` を使う。
形式: `FILE_TIMESTAMP_domain_Title.md`
- FILE_TIMESTAMP: YYYYMMDDHHmmss 形式で与えられる
- domain: ソース URL から短い識別子を取り出す（例: medium.com → "medium"）
例: `20260428143052_medium_Some Article Title.md`

## 変換形式

重要: 変換後のファイルのみを保存先パスに書き込む。解説・説明・ステータスメッセージは出力しない。

YAML frontmatter はそのまま維持する。

本文を文・節単位に分割し、各ブロックを以下の形式で出力する:

1. 英語の原文
2. 次の行に日本語訳
3. 重要語句を箇条書き: `- word: 日本語訳`
4. 次のブロックの前に空行

宣伝フッター・ニュースレター登録・著者プロフィールなどは削除する。

## 例

```
The traditional hiring process was designed for a world where companies held all the leverage.
従来の採用プロセスは、企業がすべての交渉力を握っていた時代のために設計された。
- hiring process: 採用プロセス
- leverage: 交渉力

Post a job, collect hundreds of resumes, and pick the best one.
求人を出し、何百もの履歴書を集め、最良のものを選ぶ。
- resumes: 履歴書
```
