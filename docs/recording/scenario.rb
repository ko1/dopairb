# [code, outcome] ; outcome :ok / :err
SCENARIO = [
  ["(1..100).sum", :ok],                         # 1 FIRST HIT
  ["\"dopamine\".chars.map(&:ord).sum * 1024", :ok], # 2 fast typing: 8/16/32-BIT
  ["1 + )", :err],                               # 3 SYNTAX BREAK
  ["1 + 1", :ok],                                # 4 FIXED!
  ["def boost = :on", :ok],                      # 5 NEW ABILITY
  ["2**64", :ok],                                # 6 counter
  ["[3, 1, 2].sort", :ok],                       # 7 CRITICAL wanted
  ["boost", :ok],                                # 8
  ["1 < 2", :ok],                                # 9 YES!
  ["'dopa' * 30", :ok],                          # 10 string
  ["(1..24).to_a", :ok],                         # 11 array
  ["[].first", :ok],                             # 12 nil -> COMBO 10 at (4..13) => combo 10 here? computed below
  ["Math::PI * 2", :ok],                         # 13
  ["[:fever] * 3", :ok],                         # 14
  ["7 * 111", :ok],                              # 15 JACKPOT wanted
]
