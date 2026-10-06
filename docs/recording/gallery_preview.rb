# Render gallery pieces into a labeled contact sheet PNG.
# usage: ruby docs/recording/gallery_preview.rb OUT.png [id ...]       (no ids: all pieces)
#        ruby docs/recording/gallery_preview.rb OUT.png --file lib/dopairb/gallery/foo.rb
# Each piece is drawn as the game shows it (fit into 64 cols x 24 rows = 2 px per row), scaled x4.
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "dopairb"
require "zlib"
require "fileutils"
require "tmpdir"

def png(path, px)
  h = px.size
  w = px[0].size
  raw = px.map { |row| "\0".b + row.flatten.pack("C*") }.join
  chunk = ->(t, d) { [d.bytesize].pack("N") + t + d + [Zlib.crc32(t + d)].pack("N") }
  File.binwrite(path, "\x89PNG\r\n\x1a\n".b + chunk.("IHDR", [w, h, 8, 2, 0, 0, 0].pack("NNCCCCC")) +
                      chunk.("IDAT", Zlib::Deflate.deflate(raw)) + chunk.("IEND", ""))
end

out = ARGV.shift or abort "usage: ruby gallery_preview.rb OUT.png [ids | --file path]"
G = Dopairb::Gallery
pieces = if ARGV[0] == "--file"
           ids = File.read(ARGV[1]).scan(/^\s*piece[ (]:(\w+)/).flatten.map(&:to_sym)
           ids.map { |i| G.find(i) or abort("no piece #{i}") }
         elsif ARGV.empty? then G::PIECES
         else ARGV.map { |i| G.find(i.to_sym) or abort("no piece #{i}") }
         end
S = 4
dir = Dir.mktmpdir("gprev")
files = pieces.each_with_index.map do |p, i|
  w, h = G.fit(p, 64, 24)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  px = G.pixels(p, w, h)
  ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
  bad = px.flatten(1).find { |c| !(Array === c && c.size == 3 && c.all? { |x| Integer === x && x.between?(0, 255) }) }
  warn "#{p.id}: bad pixel #{bad.inspect}" if bad
  warn "#{p.id}: slow (#{ms} ms)" if ms > 300
  big = px.flat_map { |r| [r.flat_map { |c| [c] * S }] * S }
  f = File.join(dir, format("%03d_%s.png", i, p.id))
  png(f, big)
  [f, "#{p.id}\n#{p.title[0, 34]}"]
end
args = files.flat_map { |f, label| ["-label", label.gsub("%", "%%"), f] }
system("montage", *args, "-tile", "5x", "-geometry", "+6+6", "-background", "#222", "-fill", "#eee", "-pointsize", "13", out) or abort "montage failed"
FileUtils.rm_rf(dir)
puts "wrote #{out} (#{pieces.size} pieces)"
