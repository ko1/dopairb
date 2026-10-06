# frozen_string_literal: true

require_relative "helper"
require "tmpdir"

class TestProfile < Test::Unit::TestCase
  def test_day_streak
    pr = Dopairb::Profile.new
    d = Date.new(2026, 10, 6)
    assert pr.visit(d)
    assert_equal 1, pr.streak
    assert !pr.visit(d), "same day counts once"
    pr.visit(d + 1)
    pr.visit(d + 2)
    assert_equal 3, pr.streak
    pr.visit(d + 5)
    assert_equal 1, pr.streak
  end

  def test_finish_merges_with_the_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "sub", "profile.json")
      a = Dopairb::Profile.load(path)
      b = Dopairb::Profile.load(path)
      a.finish({ score: 1000, max_combo: 4 }, collected: [:mona_lisa])
      b.finish({ score: 300, max_combo: 9 })
      c = Dopairb::Profile.load(path)
      assert_equal 1300, c.xp
      assert_equal 1000, c.best_score
      assert_equal 9, c.best_combo
      assert_equal 2, c.sessions
      assert_equal [:mona_lisa], c.gallery
      assert_equal 3, c.level
    end
  end

  def test_off_and_broken_files
    old = ENV["DOPAIRB_PROFILE"]
    ENV["DOPAIRB_PROFILE"] = "off"
    assert_nil Dopairb::Profile.default_path
    assert !Dopairb::Profile.load.persistent?
    Dir.mktmpdir do |dir|
      path = File.join(dir, "p.json")
      File.write(path, "{broken")
      assert_equal 0, Dopairb::Profile.load(path).xp
    end
  ensure
    ENV["DOPAIRB_PROFILE"] = old
  end

  def test_gallery_paints_every_piece
    Dopairb::Gallery::PIECES.each do |p|
      w, h = Dopairb::Gallery.fit(p, 60, 20)
      assert_operator w, :<=, 60
      assert_operator h, :<=, 40
      px = Dopairb::Gallery.pixels(p, w, h)
      assert px.flatten(1).all? { |c| c.size == 3 && c.all? { |v| v.between?(0, 255) } }, p.id.to_s
      assert_operator px.flatten(1).uniq.size, :>, 6, "#{p.id} is a picture, not a flat color"
    end
  end
end
