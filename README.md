# dopairb

An interactive Ruby shell that answers every keystroke, evaluation, result and exception with loud terminal effects.
It is built as an IRB extension. The design spec is [spec.md](spec.md) (in Japanese).

https://github.com/user-attachments/assets/b45e4a97-ffde-4fb2-be73-ef69d5c8af42

A 70-second session with sound (`dopairb --max --sound`); also in [docs/dopairb-demo.mp4](docs/dopairb-demo.mp4). The scripts that recorded it are in [docs/recording](docs/recording).

```
dopairb(main):001> (1..100).sum                     COMBO 00  SCORE 33  [⣿⣿⣀⣀⣀⣀⣀⣀] x1.5
                    ⠂⠌⠟⠃        <- sparks, afterglow and HUD on every keystroke

        █████ ███ ████   ████ █████    █   █ ███ █████ █
        █      █  █   █ █       █      █   █  █    █   █     <- big moments: drop, impact, shockwave, fireworks
        ████   █  ████   ███    █      █████  █    █   █
✦ FIRST HIT! ✦  +252                                          <- optional one-line badge left behind
=> 5050                                                        <- IRB's normal result output, untouched
```

## Install

dopairb is not on rubygems.org yet. Install it from the repository:

```console
$ git clone https://github.com/ko1/dopairb
$ cd dopairb
$ gem build dopairb.gemspec && gem install ./dopairb-*.gem
```

To try it without installing, run `ruby exe/dopairb` in the checkout.

## Usage

```console
$ dopairb                 # start it (IRB options are passed through)
$ dopairb --calm          # quieter: low intensity, no flash, shorter effects
$ dopairb --max           # everything at maximum; the biggest moments go full screen
$ dopairb --party         # max + full-screen flash + sound effects
$ dopairb --sound         # synthesized sound effects (--sound=bell for the terminal bell)
$ dopairb --no-flash      # suppress flashing, available from the very first start
$ DOPAIRB="intensity=low,flash=off" dopairb
```

To enable it in your regular `irb`, add this to `~/.irbrc`:

```ruby
require "dopairb"
Dopairb.enable            # also e.g. Dopairb.enable(flash: :off, intensity: :low)
```

Inside a session, the `dopa` command changes settings:

```
dopa                  show settings and session stats
dopa off|low|normal|max
dopa calm / dopa party
dopa demo             play every effect once (does not change your score)
dopa loading          show the loading screen
dopa gallery          the bonus art you have collected (`dopa gallery starry_night` shows one)
dopa flash=off duration=0.5 ...
```

### Settings

| Setting | Values | Default | Meaning |
| --- | --- | --- | --- |
| `intensity` | off / low / normal / max | normal | Overall amount. `off` behaves exactly like plain IRB |
| `motion` | on / off | on | `off` disables animation (badges only) |
| `flash` | off / soft / full | soft | `soft` flashes only the effect area, `full` inverts the whole screen |
| `sound` | off / bell / sfx | off | `sfx` plays synthesized sound effects, `bell` rings the terminal bell on big moments |
| `hud` | on / off | on | COMBO / SCORE / CHARGE on the right of the prompt line |
| `duration` | 0.1–5 | 1.0 | Length multiplier for every effect |
| `color` | auto / truecolor / 256 / 16 / none | auto | `none` when `NO_COLOR` is set |
| `trail` | none / big / all | big | Which effects leave a one-line badge |
| `charge` | 0–0.3 s | 0.12 | Wind-up before a fast result lands; 0 disables it |
| `intro` | on / off | on | Title animation at startup |
| `keys` | on / off | on | Per-keystroke effects |

## Effects

Effects come in four strengths: **small** (every key), **medium** (syntactic moments), **large** (evaluation finished) and **huge** (records and comebacks).
When several fire at once, only the biggest plays. The smaller ones are folded into its subtitle rather than queued.

| Moment | Effect |
| --- | --- |
| Typing | A spark trail right of the cursor, a brief glow on the typed character, embers falling below, a x1.0–x3.0 multiplier |
| Typing streak of 8, 16, 32 … 1024 keys | Powers of two, in big half-block letters under the input: `8-BIT RUSH!`, `16-BIT COMBO!`, `32-BIT BLAZE!!`, `64-BIT OVERDRIVE!!`, `128-BIT HYPER MODE!!`, `0x100 OVERFLOW!!!`, `2^9 GODSPEED!!!`, `1KiB TYPING LEGEND!!!`, with a bonus of 4 points per key |
| Resuming after a pause | Reignites with `CHARGE!` |
| Backspace / Delete | The deleted character shatters and falls. The next keystroke shows `RECOVERY` |
| Cursor movement | A light streak in the direction of travel |
| Closing a bracket | The matching pair pulses, `NICE!` |
| Closing a string or block | The range is highlighted, `end` shows `SEALED!` |
| Accepting a completion | A light sweeps across the completed part, `<< LOCK ON` |
| History recall | The line appears behind a scanline, `<< REWIND` |
| Continuing a multi-line input | `CHARGE LV2`… |
| Paste | One `PASTE x120` popup, no per-character effects |
| Enter | A hot band sweeps across the input line ("EXECUTE"). Evaluations longer than 0.25 s show `CHARGING`, and after 3 s a calm elapsed-time readout |
| Ordinary value | A comet flies from `=>` and lands, `+SCORE` `COMBO n` |
| `nil` | A swing and a miss (`~~~`) and a puff of smoke |
| `true` / `false` | A `YES!` / `NO!` stamp slams down |
| Big numbers (≥10,000) | Giant digits count up, then a shockwave |
| Long String / Array / Hash | Characters pour in / elements pop into place one by one |
| `def` / `class` / `module` | Unlocks like `NEW ABILITY` |
| 20+ lines of stdout | `OUTPUT RAIN` digital rain |
| SyntaxError | The input line shakes and cracks, `SYNTAX BREAK`, with the error position |
| NameError | A spotlight on that name in your input, `UNKNOWN SYMBOL` |
| NoMethodError | The link between receiver and method snaps |
| TypeError / ArgumentError | The two sides collide and explode (`TYPE CLASH` / `ARGUMENT CLASH`) |
| Other exceptions | A red flash and a glitching `FAILED` |
| Ctrl-C | The stored charge scatters, `INTERRUPTED` |
| First eval / COMBO 5, 10, 25… / eval count 10, 50, 100… | `FIRST HIT!` / `COMBO 10!` / `100 EVALS` |
| Lucky success (about 1 in 10, up to 1 in 5 with a full CHARGE) | `CRITICAL!!`: a slash, a red flash and x2 / x4 / x8 points |
| Very lucky success (1 in 67) | `JACKPOT!!`: three slot reels stop on 7-7-7, coins rain, x16 points |
| COMBO 10 and beyond | `FEVER TIME!`: every point counts double until the next error; the HUD glows in rainbow `FEVER!` |
| Beating your all-time best combo | `BEST COMBO!` |
| Level up (see [Career](#career)) | `LEVEL UP!`, then a famous painting is unveiled full screen as bonus art |
| Numeric record (more than doubled) | `NEW RECORD` |
| Success right after an error | `FIXED!` (after one error) / `COMEBACK!` (after a streak), both huge |
| Exit | A full-screen finale: the title drops, stats slam in one by one, the total score counts up under a drum roll, a rank is stamped (S/A/B/C with a cheerful title), then fireworks. The result is left behind as a plain table |

Error effects name the kind of error. They never make fun of the failure.

## Career

Between sessions dopairb keeps a small profile: lifetime XP (the sum of your scores), level, best score, best combo, a day streak and the bonus art you have collected.
Levels need powers of two: LV 2 at 512 XP, LV 3 at 1,024, LV 4 at 2,048, and so on.
Each level-up unveils a painting: Hokusai's *The Great Wave off Kanagawa* and *Fine Wind, Clear Morning*, van Gogh's *The Starry Night*, Leonardo's *Mona Lisa* and Munch's *The Scream*, all painted procedurally in half blocks (no image files ship with the gem). New ones come first.
The startup title shows your level and day streak, and the finale shows `NEW BEST!` and an XP bar.

The profile is `~/.local/state/dopairb/profile.json` (`$XDG_STATE_HOME` is honored). Set `DOPAIRB_PROFILE=path` to use another file, or `DOPAIRB_PROFILE=off` to keep nothing; levels are then not shown.
Non-interactive runs never touch it.

`DOPAIRB_SEED=n` makes the luck (critical hits, jackpots, particles) repeatable, which helps when recording a demo.

## Sound

With `sound=sfx`, every effect has a sound: key clicks, `NICE!` chimes, a comet ping, a stamp thump, a count-up that ends in a boom, fanfares and explosions for the big moments, a buzz or crack for errors.
All sounds are synthesized in Ruby at runtime and cached as WAV files in the temp directory. No audio files ship with the gem.

They are played by the first player found:

- `paplay` (PulseAudio, including WSLg on WSL2)
- `afplay` (macOS)
- `aplay` (ALSA)
- `powershell.exe` on WSL without WSLg

The finale's sound is one track synthesized on the same timeline as the animation (a tick and a rising note per stat row, a drum roll, a boom, a fanfare, fireworks) and stretched with `duration`.
Sounds are rendered once and reused by later sessions. At startup, a Ractor renders the missing ones in parallel with the REPL, so typing is not slowed down (a thread is used where Ractor is unavailable). The startup sound is rendered first. On a start without cached sounds (the first run, or after an upgrade), a loading screen (a cat running along a pastel progress bar) is shown until it is ready. `dopa loading` shows it any time.
Players run as separate processes, so the REPL never waits for them.
PowerShell takes a few hundred milliseconds to start, so with it only the result effects make sound, not every keystroke.
When no player is found, `sfx` falls back to the terminal bell on big moments.
Sound plays on the machine that runs dopairb, so over ssh you will not hear it.

## Readable, never broken

- IRB evaluates and prints as usual. `=> value`, exception messages and backtraces come from IRB itself.
  Effects are drawn in a temporary area and cleared. Only your input, the program's output and the result (plus an optional one-line badge) stay in the scrollback.
- dopairb never calls your `#inspect` / `#to_s` for its effects. It classifies values only with `Module#===` and `bind_call` on built-in methods.
- When your program writes to stdout or stderr during an evaluation, the waiting display and any effect get out of the way immediately. While a `system` / `spawn` / `IO.popen` child might write straight to the terminal, nothing is decorated.
- Pressing a key during an effect ends it at once, and the key goes to Reline as usual. Per-keystroke effects pause while you paste.
- Non-interactive runs (pipes, redirects), `TERM=dumb` and `intensity=off` emit no control sequences at all. `NO_COLOR` emits no color codes.
- On narrow terminals, big-font banners fall back to spaced-out one-line text, then to badges only. On terminals where East Asian Ambiguous characters are two columns wide, box-drawing and block characters are replaced with ASCII or braille.
- An exception inside an effect never reaches the REPL. Set `DOPAIRB_DEBUG=path` to log it.

## Implementation

dopairb extends IRB and has no evaluation engine of its own. All dependencies on IRB and Reline internals live in two files.

- `lib/dopairb/reline_adapter.rb` (Reline 0.5–0.7, tested with 0.6.3)
  - Public API: `Reline.add_dialog_proc` (three dialogs: HUD, spark trail, effect strip) and `output_modifier_proc` (glow on the input).
  - Internals:
    - `LineEditor#input_key`: before/after comparison of each key.
    - `#handle_signal`: Reline calls it every 10 ms while waiting for input, so it serves as the animation tick.
    - `#render`.
    - `#render_finished`: records how the submitted input looks on screen.
    - `Core#readmultiline`.
- `lib/dopairb/irb_adapter.rb` (IRB 1.14–1.x, tested with 1.18.0)
  - Public API: `IRB::Command.register(:dopa)` and `IRB.conf[:AT_EXIT]`.
  - Internals: `IRB::Context#evaluate` (around each statement) and `IRB::WorkSpace#filter_backtrace` (hides dopairb's own frames).

The rest is terminal-independent logic:

- `Game`: COMBO / CHARGE / SCORE.
- `Probe`: safe classification of values and exceptions.
- `InputFx`: per-keystroke effects.
- `Director` and the scenes in `scenes/`.
- `Canvas`: a cell grid with a braille sub-pixel layer.
- `Stage`: borrows a few rows at the cursor, draws, and restores the input line exactly.

### Open questions in the spec (§11) and what was decided

- The HUD is not pinned to the top of the screen. It sits at the right end of the prompt line while typing and disappears when the input is submitted.
- Output printed during evaluation (`puts` etc.) is not decorated. Its lines are only counted, to trigger `OUTPUT RAIN`.
- Scores live for the session only and are not saved.
- Effects use Unicode. Any glyph that is not one column wide is swapped for ASCII or braille at runtime.
- Start it with the `dopairb` command, or call `Dopairb.enable` in `.irbrc`.
- IRB sessions entered via `binding.irb` get the same Context hook. The result screen appears only when the outermost session ends.

## Performance

These are rough numbers from a local machine, not a formal benchmark.
Processing one key (`LineEditor#update` + `render`) takes about 3 ms in plain IRB and about 5.6 ms in dopairb.
With keys typed 30 ms apart, both follow the input within 1 ms.
While an effect is running, the screen is redrawn at up to 30 fps, about 1 ms per frame.

## Development

```console
$ bundle exec rake test     # unit tests + every scene x width x color depth + PTY integration tests
```

The integration tests (`test/test_integration.rb`) start dopairb on a pseudo terminal. They rebuild the screen with a small VT100 model (`test/support/vt.rb`) and check the acceptance criteria of spec §10:

- results and error messages remain as plain text
- fast typing and pastes do not change the input
- Ctrl-C works
- narrow terminals work
- `NO_COLOR` emits no color codes
- non-interactive runs contain no control sequences
- `intensity=off` behaves as plain IRB

They require `setsid`.

## Known limitations

- Output that does not come from a child process (a C extension writing to fd 1 directly, `$stdout.reopen`, …) cannot be detected and may mix with the waiting display during an evaluation.
- When a multi-line input grows at the bottom of the screen, the effect strip below the input disappears (the HUD and spark trail remain). The strip is also hidden while completion candidates are shown.
- When IRB shows a long result in a pager (`less`), the effect finishes before the pager starts.
- If the terminal is resized in the middle of an effect, the rest of that effect may be garbled. The next effect uses the new width.

## License

MIT
