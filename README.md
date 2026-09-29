# dopairb

入力・評価・結果・例外のすべてを派手な演出で返す、IRB 拡張の対話環境。
仕様は [spec.md](spec.md)。

```
dopairb(main):001> (1..100).sum                     COMBO 00  SCORE 33  [⣿⣿⣀⣀⣀⣀⣀⣀] x1.5
                    ⠂⠌⠟⠃        ← 打鍵ごとの火花・残像・HUD

        █████ ███ ████   ████ █████    █   █ ███ █████ █
        █      █  █   █ █       █      █   █  █    █   █     ← 節目の大演出（落下→着弾→衝撃波→花火）
        ████   █  ████   ███    █      █████  █    █   █
✦ FIRST HIT! ✦  +252                                          ← 演出後に残る 1 行バッジ（任意）
=> 5050                                                        ← IRB の通常の結果表示はそのまま
```

## 使い方

```console
$ dopairb                 # 起動（IRB のオプションもそのまま渡せる）
$ dopairb --calm          # 控えめ（low / フラッシュなし / 短め）
$ dopairb --max           # 最大。特大イベントは代替スクリーンで全画面演出
$ dopairb --party         # max + 全画面フラッシュ + ベル
$ dopairb --no-flash      # 点滅を抑える（初回起動から指定可）
$ DOPAIRB="intensity=low,flash=off" dopairb
```

普段の `irb` で有効にするには `~/.irbrc` に:

```ruby
require "dopairb"
Dopairb.enable            # Dopairb.enable(flash: :off, intensity: :low) なども可
```

セッション中は `dopa` コマンドで切り替えられる:

```
dopa                  設定とセッションの統計
dopa off|low|normal|max
dopa calm / dopa party
dopa demo             全演出を一通り再生（スコアは変わらない）
dopa flash=off duration=0.5 ...
```

### 設定

| 設定 | 値 | 既定 | 内容 |
| --- | --- | --- | --- |
| `intensity` | off / low / normal / max | normal | 全体量。off は素の IRB と同じ |
| `motion` | on / off | on | off はアニメーションなし（バッジのみ） |
| `flash` | off / soft / full | soft | soft は演出領域だけ、full は画面全体を反転 |
| `sound` | on / off | off | 大きな節目で端末ベル |
| `hud` | on / off | on | プロンプト行右端の COMBO / SCORE / CHARGE |
| `duration` | 0.1–5 | 1.0 | 全演出の長さの倍率 |
| `color` | auto / truecolor / 256 / 16 / none | auto | `NO_COLOR` があれば none |
| `trail` | none / big / all | big | 演出後に 1 行バッジを残す対象 |
| `charge` | 0–0.3 秒 | 0.12 | 速い評価の着弾前の「溜め」。0 で無効 |
| `intro` | on / off | on | 起動タイトル |
| `keys` | on / off | on | 毎キー演出 |

## 演出（緩急）

強さは **小（毎キー）→ 中（構文上の節目）→ 大（評価完了）→ 特大（記録・復帰）**。
同時に起きたら大きい方だけを再生し、小さい方はサブタイトルに畳む。キューには積まない。

| 場面 | 演出 |
| --- | --- |
| 文字入力 | カーソル右に火花の尾、打った文字の一瞬の発光、下に落ちる火の粉、倍率 x1.0–x3.0 |
| 間を置いて再開 | `CHARGE!` で再点火 |
| Backspace / Delete | 消した文字が砕けて落ちる。直後の入力で `RECOVERY` |
| カーソル移動 | 移動方向への光跡 |
| 括弧を閉じる | 対応する括弧の対が脈打ち `NICE!` |
| 文字列・ブロックを閉じる | 範囲をハイライト、`end` で `SEALED!` |
| 補完の確定 | 確定部分に光が走り `<< LOCK ON` |
| 履歴呼び出し | 左から走査線で現れ `<< REWIND` |
| 複数行の継続 | `CHARGE LV2`… |
| 貼り付け | 1 回だけ `PASTE x120`（1 文字ずつは鳴らさない） |
| Enter | 入力行を熱い帯が走る「EXECUTE」。0.25 秒超の評価は `CHARGING` 表示、3 秒超で静かな経過時間表示 |
| 通常の値 | `=>` から彗星が飛んで着弾、`+SCORE` `COMBO n` |
| `nil` | 空振り（`~~~`）と煙 |
| `true` / `false` | `YES!` / `NO!` のスタンプが叩きつけられる |
| 大きな数（≥10,000） | 巨大数字でカウントアップ→衝撃波 |
| 長い String / Array / Hash | 文字が流れ込む / 要素が 1 個ずつ弾けて並ぶ |
| `def` / `class` / `module` | `NEW ABILITY` などのアンロック |
| 標準出力が 20 行以上 | `OUTPUT RAIN` のデジタルレイン |
| 構文エラー | 入力行が揺れて亀裂が走り `SYNTAX BREAK`、エラー位置を表示 |
| `NameError` | 入力中のその名前にスポットライト、`UNKNOWN SYMBOL` |
| `NoMethodError` | レシーバとメソッドをつなぐ線が切れる |
| `TypeError` / `ArgumentError` | 両側がぶつかって爆発（`TYPE CLASH` / `ARGUMENT CLASH`） |
| その他の例外 | 赤いフラッシュとグリッチの `FAILED` |
| Ctrl-C | 溜めたチャージが散って `INTERRUPTED` |
| 初回 / COMBO 5,10,25… / 評価回数 10,50,100… | `FIRST HIT!` / `COMBO 10!` / `100 EVALS` |
| 数値の記録更新（2 倍超） | `NEW RECORD` |
| エラー直後の成功 | `FIXED!`（1 回）/ `COMEBACK!`（連続エラー後）— 特大 |
| 終了 | カウントアップするリザルト画面。最後は普通の表として残る |

失敗演出の文言は例外の種類を伝えるだけで、失敗を笑う言葉は使わない。

## 読める・壊さない

- IRB の評価・表示はそのまま。`=> value`、例外本文、バックトレースは IRB が普段どおり出す。
  演出は一時的な領域に描いて消し、スクロールバックには入力・出力・結果（と任意のバッジ 1 行）だけが残る。
- ユーザーの `#inspect` / `#to_s` は演出のために呼ばない（型判定は `Module#===` と組み込みメソッドの `bind_call` のみ）。
- 評価中にプログラムが標準出力・標準エラーに書くと、待機表示や演出は即座に退く。`system` / `spawn` / `IO.popen` の子プロセスが端末に直接書く可能性がある間は装飾しない。
- 演出中にキーを押すと即座に収束する（キーは Reline にそのまま渡る）。貼り付け中は毎キー演出を止める。
- 非対話（パイプ・リダイレクト）、`TERM=dumb`、`intensity=off` では制御文字を一切出さない。`NO_COLOR` では色コードを出さない。
- 端末が狭いと大文字フォント → 字間を空けた 1 行表示 → バッジのみ、と縮退する。East Asian Ambiguous 幅の端末では罫線・ブロック記号を ASCII / 点字に置き換える。
- 演出側で例外が起きても REPL には影響させない（`DOPAIRB_DEBUG=path` で記録）。

## 実装

IRB を拡張する形で、評価エンジンは持たない。内部実装への依存は 2 ファイルに隔離している。

- `lib/dopairb/reline_adapter.rb`（Reline 0.5–0.7, 動作確認 0.6.3）
  - 公開 API: `Reline.add_dialog_proc`（HUD・火花の尾・演出帯の 3 つの dialog）、`output_modifier_proc`（入力の発光）
  - 内部: `LineEditor#input_key`（キーの前後比較）、`#handle_signal`（入力待ち中 10ms ごとに呼ばれるのでアニメーションの tick に使う）、`#render`、`#render_finished`（確定した入力行の画面上の姿を記録）、`Core#readmultiline`
- `lib/dopairb/irb_adapter.rb`（IRB 1.14–1.x, 動作確認 1.18.0）
  - 公開 API: `IRB::Command.register(:dopa)`、`IRB.conf[:AT_EXIT]`
  - 内部: `IRB::Context#evaluate`（1 文の評価の前後）、`IRB::WorkSpace#filter_backtrace`（dopairb 自身のフレームを隠す）

残りは端末非依存のロジック: `Game`（COMBO / CHARGE / SCORE）、`Probe`（値・例外の安全な分類）、`InputFx`（毎キー演出）、`Director` とシーン群（`scenes/`）、`Canvas`（点字サブピクセル付きセルグリッド）、`Stage`（カーソル位置から数行を借りて描き、入力行を元どおりに戻す）。

### 仕様の未決定事項（§11）について今回決めたこと

- HUD は画面上部固定ではなく、入力中のプロンプト行右端に一時表示（入力確定で消える）。
- `puts` などの評価途中の出力は装飾しない。行数だけ数えて `OUTPUT RAIN` の判定に使う。
- スコアはセッション内のみ。保存しない。
- 演出素材は Unicode 中心。幅が 1 でない記号は実行時に ASCII / 点字へ差し替える。
- 起動は `dopairb` コマンド、または `.irbrc` で `Dopairb.enable`。
- `binding.irb` から入った IRB でも同じ Context フックが効く（リザルト画面は最外のセッション終了時のみ）。

## 性能の目安

ローカル機での概算（正式なベンチマークではない）。1 キーの処理（`LineEditor#update` + `render`）は
素の IRB 約 3ms に対し dopairb 約 5.6ms。30ms 間隔の入力への追従遅れはどちらも 1ms。
演出が動いている間は最大 30fps で再描画し、1 フレーム約 1ms。
方法と生データ: `~/ruby/src/trials/2026-09-29-dopairb-key-latency/`

## 開発

```console
$ bundle exec rake test     # 単体 + 全シーン × 幅 × 色数の描画検査 + PTY 統合テスト
```

統合テスト（`test/test_integration.rb`）は疑似端末上で dopairb を起動し、`test/support/vt.rb` の小さな VT100 モデルで画面を再構成して、仕様 §10 の受け入れ条件（結果とエラー本文が普通のテキストで残る、高速入力・貼り付けで入力が変わらない、Ctrl-C、狭い端末、`NO_COLOR`、非対話で制御文字なし、`intensity=off` で素の IRB）を確認する。`setsid` が必要。

## 既知の制限

- 子プロセス以外（C 拡張が fd 1 に直接書く、`$stdout.reopen` など）の出力は検知できず、評価中の待機表示と混ざることがある。
- 画面最下段で複数行入力が伸びると、入力下の演出帯は出なくなる（HUD と火花の尾は出る）。補完候補の表示中も演出帯は隠れる。
- IRB がページャ（`less`）で長い結果を表示する場合、演出はその前に終わる。
- 演出の途中で端末幅が変わると、その演出の残りは崩れることがある（次の演出からは新しい幅）。

## License

MIT
