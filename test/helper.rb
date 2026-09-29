# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "dopairb"
require "test/unit"

module DopairbTestHelper
  SGR = /\e\[[\d;]*m/

  def strip_sgr(s) = s.gsub(SGR, "")

  def assert_only_sgr(s, msg = nil)
    rest = s.gsub(SGR, "")
    assert_not_match(/[\x00-\x1f\x7f]/, rest, msg || "unexpected control characters in #{s.inspect}")
  end

  def fake_clock(start = 100.0)
    t = [start]
    [-> { t[0] }, ->(dt) { t[0] += dt }]
  end
end
