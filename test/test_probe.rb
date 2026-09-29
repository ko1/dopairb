# frozen_string_literal: true

require_relative "helper"

class TestProbe < Test::Unit::TestCase
  P = Dopairb::Probe

  class Loud
    def inspect = raise("inspect must not be called")
    def to_s = raise("to_s must not be called")
    def class = raise("class must not be called")
  end

  class LoudString < String
    def inspect = raise("nope")
    def length = raise("nope")
  end

  def test_basic_types
    assert_equal({ type: :nil }, P.value(nil))
    assert_equal :true, P.value(true)[:type]
    assert_equal :false, P.value(false)[:type]
    assert_equal({ type: :integer, value: 42 }, P.value(42))
    assert_equal :float, P.value(1.5)[:type]
    assert_equal 3, P.value([1, 2, 3])[:size]
    assert_equal :hash, P.value({ a: 1 })[:type]
    assert_equal "foo", P.value(:foo)[:name]
  end

  def test_does_not_call_user_methods
    assert_equal "TestProbe::Loud", P.value(Loud.new)[:class_name]
    s = LoudString.new("x" * 50)
    assert_equal 50, P.value(s)[:length]
    assert_equal "BasicObject", P.value(BasicObject.new)[:class_name]
  end

  def test_huge_integer_is_not_stringified
    info = P.value(10**5000)
    assert_equal :huge, info[:type]
    assert_equal 5001, info[:digits]
  end

  def test_string_head_is_sanitized
    info = P.value("a\e[31mb\nc\u0000")
    assert_not_match(/[\x00-\x1f]/, info[:head])
  end

  def test_definitions
    assert_equal({ type: :definition, what: :method, name: "foo" }, P.value(:foo, "def foo(x) = x"))
    assert_equal :class, P.value(nil, "class Foo; end")[:what]
    assert_equal "A::B", P.value(nil, "module A::B; end")[:name]
    assert_equal :symbol, P.value(:foo, ":foo")[:type]
  end

  def test_exceptions
    syn = P.exception(SyntaxError.new("x"), "1 + )")
    assert_equal :syntax, syn[:type]
    assert_equal 1, syn[:line]
    assert_equal 4, syn[:column]
    ne = (undefined_name_xyz rescue $!)
    assert_equal({ type: :name, name: "undefined_name_xyz" }, P.exception(ne).slice(:type, :name))
    nm = (1.shout rescue $!)
    i = P.exception(nm)
    assert_equal [:nomethod, "shout", "Integer"], i.values_at(:type, :name, :receiver)
    te = (1 + "1" rescue $!)
    assert_equal %w[String Integer], P.exception(te)[:sides]
    ae = ([].first(1, 2) rescue $!)
    assert_equal ["given 2", "expected 0..1"], P.exception(ae)[:sides]
    assert_equal :interrupt, P.exception(Interrupt.new)[:type]
    assert_equal :other, P.exception(RuntimeError.new("x"))[:type]
  end

  def test_exception_with_raising_message
    klass = Class.new(StandardError) { def to_s = raise("boom") }
    info = P.exception(klass.new)
    assert_equal :other, info[:type]
    assert_equal "", info[:message]
    overridden = Class.new(StandardError) { def message = raise("never called") }
    assert_kind_of String, P.exception(overridden.new)[:message]
  end
end
