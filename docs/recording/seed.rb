require "dopairb"
load File.join(__dir__, "scenario.rb")
G = Dopairb::Game
want_crit = ARGV[0].split(",").map(&:to_i)
want_jp = ARGV[1].to_i
oks = SCENARIO.each_index.select { |i| SCENARIO[i][1] == :ok }.map { _1 + 1 }
(1..2_000_000).each do |seed|
  r = Random.new(seed)
  out = {}
  bad = false
  oks.each do |n|
    x = r.rand
    if x < G::JACKPOT_CHANCE then out[n] = :jp
    elsif x < G::CRIT_CHANCE then out[n] = [:crit, G::CRIT_MULTS.sample(random: r)]
    elsif x < G::CRIT_CHANCE + G::CRIT_CHARGE_BONUS then bad = true; break
    end
  end
  next if bad
  next unless out.keys.sort == (want_crit + [want_jp]).sort && out[want_jp] == :jp && out[want_crit[0]][1] == 8
  p [seed, out]
  break
end
