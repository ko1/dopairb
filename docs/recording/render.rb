# Replay a recorded session through a VT model and render it to MP4 (with the sound track).
# usage: ruby render.rb OUTDIR [fps]
require "open3"
require "fileutils"
require "tempfile"
ROOT = File.expand_path("../..", __dir__)
require "#{ROOT}/test/support/vt"

DIR = File.expand_path(ARGV[0] || "out", __dir__)
FPS = (ARGV[1] || 30).to_i
CW = 10
CH = 20
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
DEF_FG = [214, 216, 226].freeze
DEF_BG = [14, 14, 22].freeze

PALETTE16 = [[0, 0, 0], [205, 49, 49], [13, 188, 121], [229, 229, 16], [36, 114, 200], [188, 63, 188], [17, 168, 205], [229, 229, 229],
             [102, 102, 102], [241, 76, 76], [35, 209, 139], [245, 245, 67], [59, 142, 234], [214, 112, 214], [41, 184, 219], [255, 255, 255]].freeze
def xterm256(n)
  return PALETTE16[n] if n < 16
  if n < 232
    n -= 16
    l = ->(v) { v.zero? ? 0 : 55 + v * 40 }
    [l.(n / 36), l.((n / 6) % 6), l.(n % 6)]
  else
    v = 8 + (n - 232) * 10
    [v, v, v]
  end
end

# VT that keeps full SGR state as [fg, bg, bold, dim, reverse] and the cursor visibility.
class RVT < VT
  attr_reader :cursor_on, :reverse_screen

  def initialize(*)
    super
    @attr = [nil, nil, false, false, false]
    @cursor_on = true
    @reverse_screen = false
  end

  def csi(priv, params, final)
    if final == "m" && priv == ""
      ps = params.split(";").map(&:to_i)
      ps = [0] if ps.empty?
      a = @attr.dup
      i = 0
      while i < ps.size
        p = ps[i]
        case p
        when 0 then a = [nil, nil, false, false, false]
        when 1 then a[2] = true
        when 2 then a[3] = true
        when 22 then a[2] = a[3] = false
        when 7 then a[4] = true
        when 27 then a[4] = false
        when 30..37 then a[0] = PALETTE16[p - 30]
        when 90..97 then a[0] = PALETTE16[p - 90 + 8]
        when 40..47 then a[1] = PALETTE16[p - 40]
        when 100..107 then a[1] = PALETTE16[p - 100 + 8]
        when 39 then a[0] = nil
        when 49 then a[1] = nil
        when 38, 48
          k = p == 38 ? 0 : 1
          if ps[i + 1] == 5
            a[k] = xterm256(ps[i + 2].to_i)
            i += 2
          elsif ps[i + 1] == 2
            a[k] = ps[i + 2, 3].map(&:to_i)
            i += 4
          end
        end
        i += 1
      end
      @attr = a
      @style = a == [nil, nil, false, false, false] ? nil : a.freeze
      return
    end
    if priv == "?" && %w[h l].include?(final)
      ps = params.split(";").map(&:to_i)
      @cursor_on = final == "h" if ps.include?(25)
      @reverse_screen = final == "h" if ps.include?(5)
    end
    super
  end
end

# ---- glyphs ---------------------------------------------------------------
GLYPH_CACHE = File.join(DIR, "glyphs.marshal")
$glyphs = File.exist?(GLYPH_CACHE) ? Marshal.load(File.binread(GLYPH_CACHE)) : {}

def block_mask(ch)
  m = Array.new(CH) { Array.new(CW, 0) }
  fill = ->(x0, y0, x1, y1, v = 255) { (y0...y1).each { |y| (x0...x1).each { |x| m[y][x] = v } } }
  case ch
  when "█" then fill.(0, 0, CW, CH)
  when "▀" then fill.(0, 0, CW, CH / 2)
  when "▄" then fill.(0, CH / 2, CW, CH)
  when "░" then fill.(0, 0, CW, CH, 64)
  when "▒" then fill.(0, 0, CW, CH, 128)
  when "▓" then fill.(0, 0, CW, CH, 192)
  else
    o = ch.ord
    return nil unless (0x2800..0x28ff).cover?(o)
    bits = o - 0x2800
    dots = [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2], [0, 3], [1, 3]]
    dots.each_with_index do |(dx, dy), b|
      next if bits[b].zero?
      x = 2 + dx * 4
      y = 2 + dy * 5
      fill.(x, y, x + 2, y + 3)
    end
  end
  m.map { |r| r.pack("C*") }
end

def glyph_mask(ch, bold)
  key = [ch, bold]
  return $glyphs[key] if $glyphs.key?(key)
  mask = block_mask(ch)
  unless mask
    text = ch.gsub("\\") { "\\\\" }.gsub("%", "%%")
    text = "\\" + text if text.start_with?("@")
    out, st = Open3.capture2("convert", "-size", "#{CW}x#{CH}", "xc:black", "-font", bold ? BOLD : FONT, "-pointsize", "16",
                             "-fill", "white", "-annotate", "+0+15", text, "-depth", "8", "gray:-", binmode: true)
    mask = st.success? && out.bytesize == CW * CH ? (0...CH).map { |y| out.byteslice(y * CW, CW) } : Array.new(CH) { "\0" * CW }
  end
  $glyphs[key] = mask
end

$cells = {}
def cell_rows(ch, fg, bg, bold)
  key = [ch, fg, bg, bold]
  $cells[key] ||= begin
    if ch == " " || ch.empty?
      row = bg.pack("C*") * CW
      Array.new(CH, row)
    else
      glyph_mask(ch, bold).map do |mrow|
        s = +"".b
        mrow.each_byte do |a|
          k = a / 255.0
          s << [(bg[0] + (fg[0] - bg[0]) * k).round, (bg[1] + (fg[1] - bg[1]) * k).round, (bg[2] + (fg[2] - bg[2]) * k).round].pack("C*")
        end
        s
      end
    end
  end
end

def frame(vt)
  rows = vt.rows
  cols = vt.cols
  scr = vt.screen
  cy, cx = vt.cursor
  out = +"".b
  rows.times do |y|
    line = scr[y]
    cells = Array.new(cols) do |x|
      c = line[x]
      ch = c.ch
      fg, bg, bold, dim, rev = c.style || [nil, nil, false, false, false]
      fg ||= DEF_FG
      bg ||= DEF_BG
      fg = fg.map { |v| (v * 0.6).round } if dim
      fg, bg = bg, fg if rev
      fg, bg = bg, fg if vt.reverse_screen
      if vt.cursor_on && !vt.alt && y == cy && x == cx
        fg, bg = DEF_BG, [200, 200, 210]
      end
      ch = " " if ch.empty? # right half of a wide char: drawn by the left half overflow (approximation)
      cell_rows(ch, fg, bg, bold)
    end
    CH.times { |py| cells.each { |cr| out << cr[py] } }
  end
  out
end

# ---- replay -------------------------------------------------------------------
data = Marshal.load(File.binread(File.join(DIR, "session.raw")))
vt = RVT.new(data[:rows], data[:cols])
W = data[:cols] * CW
H = data[:rows] * CH
chunks = data[:chunks]
dur = data[:duration]
nframes = ((dur + 2.5) * FPS).ceil # hold the last frame a moment

# sound track
rate = 22_050
track = Array.new((dur * rate).ceil + rate * 4, 0.0)
File.readlines(File.join(DIR, "sound.log")).each do |l|
  at, path = l.split(" ", 2)
  path = path.strip
  next unless File.exist?(path)
  off = ((at.to_f - data[:t0]) * rate).round
  pcm = File.binread(path).byteslice(44..).unpack("s<*")
  pcm.each_with_index { |v, i| j = off + i; track[j] += v / 32_768.0 if j >= 0 && j < track.size }
end
peak = track.map(&:abs).max
k = peak > 0.95 ? 0.95 / peak : 1.0
wav = File.join(DIR, "track.wav")
pcm = track.map { |v| (v * k * 32_767).round }.pack("s<*")
File.binwrite(wav, ["RIFF", 36 + pcm.bytesize, "WAVE", "fmt ", 16, 1, 1, rate, rate * 2, 2, 16, "data", pcm.bytesize].pack("a4Va4a4VvvVVvva4V") + pcm)

mp4 = File.join(DIR, "dopairb-demo.mp4")
cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "#{W}x#{H}", "-r", FPS.to_s, "-i", "-",
       "-i", wav, "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k",
       "-shortest", "-movflags", "+faststart", mp4]
ci = 0
last = nil
stills = (ENV["STILLS"] || "").split(",").map(&:to_f)
Open3.popen2(*cmd) do |stdin, _out, th|
  stdin.binmode
  nframes.times do |f|
    t = f.fdiv(FPS)
    changed = false
    while ci < chunks.size && chunks[ci][0] <= t
      vt.feed(chunks[ci][1])
      ci += 1
      changed = true
    end
    last = frame(vt) if changed || last.nil?
    stdin.write(last)
    if (s = stills.find { |x| (x - t).abs < 0.5 / FPS })
      IO.popen(["convert", "-size", "#{W}x#{H}", "-depth", "8", "rgb:-", File.join(DIR, format("still-%06.2f.png", s))], "wb") { |io| io.write(last) }
    end
    $stderr.print "\r#{f + 1}/#{nframes}" if (f % 100).zero?
  end
  stdin.close
  th.value
end
File.binwrite(GLYPH_CACHE, Marshal.dump($glyphs))
$stderr.puts
puts "wrote #{mp4} (#{dur.round(1)}s, #{W}x#{H})"
