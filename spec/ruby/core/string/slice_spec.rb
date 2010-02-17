require File.dirname(__FILE__) + '/../../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes.rb'
require File.dirname(__FILE__) + '/shared/slice.rb'

describe "String#slice" do
  it_behaves_like :string_slice, :slice
end

describe "String#slice with index, length" do
  it_behaves_like :string_slice_index_length, :slice
end

describe "String#slice with Range" do
  it_behaves_like :string_slice_range, :slice
end

describe "String#slice with Regexp" do
  it_behaves_like :string_slice_regexp, :slice
end

describe "String#slice with Regexp, index" do
  it_behaves_like :string_slice_regexp_index, :slice
end

ruby_version_is "1.9" do
  describe "String#slice with Regexp, group" do
    it_behaves_like :string_slice_regexp_group, :slice
  end
end

describe "String#slice with String" do
  it_behaves_like :string_slice_string, :slice
end

describe "String#slice! with index" do
  it "deletes and return the char at the given position" do
    a = "hello"
    a.slice!(1).should == ?e
    a.should == "hllo"
    a.slice!(-1).should == ?o
    a.should == "hll"
  end

  it "returns nil if idx is outside of self" do
    a = "hello"
    a.slice!(20).should == nil
    a.should == "hello"
    a.slice!(-20).should == nil
    a.should == "hello"
  end

  ruby_version_is ""..."1.9" do 
    it "raises a TypeError if self is frozen" do
      lambda { "hello".freeze.slice!(1) }.should raise_error(TypeError)
    end
  end

  ruby_version_is "1.9" do 
    it "raises a RuntimeError if self is frozen" do
      lambda { "hello".freeze.slice!(1)  }.should raise_error(RuntimeError)
      lambda { "hello".freeze.slice!(10) }.should raise_error(RuntimeError)
      lambda { "".freeze.slice!(0)       }.should raise_error(RuntimeError)
    end
  end

  ruby_version_is ""..."1.9" do 
    it "doesn't raise a TypeError if self is frozen and idx is outside of self" do
      "hello".freeze.slice!(10).should be_nil
      "".freeze.slice!(0).should be_nil
    end
  end

  it "calls to_int on index" do
    "hello".slice!(0.5).should == ?h

    obj = mock('1')
    # MRI calls this twice so we can't use should_receive here.
    def obj.to_int() 1 end
    "hello".slice!(obj).should == ?e

    obj = mock('1')
    def obj.respond_to?(name) name == :to_int ? true : super; end
    def obj.method_missing(name, *) name == :to_int ? 1 : super; end
    "hello".slice!(obj).should == ?e
  end
end

describe "String#slice! with index, length" do
  it "deletes and returns the substring at idx and the given length" do
    a = "hello"
    a.slice!(1, 2).should == "el"
    a.should == "hlo"

    a.slice!(1, 0).should == ""
    a.should == "hlo"

    a.slice!(-2, 4).should == "lo"
    a.should == "h"
  end

  it "always taints resulting strings when self is tainted" do
    str = "hello world"
    str.taint

    str.slice!(0, 0).tainted?.should == true
    str.slice!(2, 1).tainted?.should == true
  end

  it "returns nil if the given position is out of self" do
    a = "hello"
    a.slice(10, 3).should == nil
    a.should == "hello"

    a.slice(-10, 20).should == nil
    a.should == "hello"
  end

  it "returns nil if the length is negative" do
    a = "hello"
    a.slice(4, -3).should == nil
    a.should == "hello"
  end

  ruby_version_is "1.9" do 
    it "raises a RuntimeError if self is frozen" do
      lambda { "hello".freeze.slice!(1, 2)  }.should raise_error(RuntimeError)
      lambda { "hello".freeze.slice!(10, 3) }.should raise_error(RuntimeError)
      lambda { "hello".freeze.slice!(-10, 3)}.should raise_error(RuntimeError)
      lambda { "hello".freeze.slice!(4, -3) }.should raise_error(RuntimeError)
      lambda { "hello".freeze.slice!(10, 3) }.should raise_error(RuntimeError)
      lambda { "hello".freeze.slice!(-10, 3)}.should raise_error(RuntimeError)
      lambda { "hello".freeze.slice!(4, -3) }.should raise_error(RuntimeError)
    end
  end

  it "calls to_int on idx and length" do
    "hello".slice!(0.5, 2.5).should == "he"

    obj = mock('2')
    def obj.to_int() 2 end
    "hello".slice!(obj, obj).should == "ll"

    obj = mock('2')
    def obj.respond_to?(name) name == :to_int; end
    def obj.method_missing(name, *) name == :to_int ? 2 : super; end
    "hello".slice!(obj, obj).should == "ll"
  end

  it "returns subclass instances" do
    s = StringSpecs::MyString.new("hello")
    s.slice!(0, 0).should be_kind_of(StringSpecs::MyString)
    s.slice!(0, 4).should be_kind_of(StringSpecs::MyString)
  end
end

describe "String#slice! Range" do
  it "deletes and return the substring given by the offsets of the range" do
    a = "hello"
    a.slice!(1..3).should == "ell"
    a.should == "ho"
    a.slice!(0..0).should == "h"
    a.should == "o"
    a.slice!(0...0).should == ""
    a.should == "o"

    # Edge Case?
    "hello".slice!(-3..-9).should == ""
  end

  it "returns nil if the given range is out of self" do
    a = "hello"
    a.slice!(-6..-9).should == nil
    a.should == "hello"

    b = "hello"
    b.slice!(10..20).should == nil
    b.should == "hello"
  end

  it "always taints resulting strings when self is tainted" do
    str = "hello world"
    str.taint

    str.slice!(0..0).tainted?.should == true
    str.slice!(2..3).tainted?.should == true
  end

  it "returns subclass instances" do
    s = StringSpecs::MyString.new("hello")
    s.slice!(0...0).should be_kind_of(StringSpecs::MyString)
    s.slice!(0..4).should be_kind_of(StringSpecs::MyString)
  end

  it "calls to_int on range arguments" do
    from = mock('from')
    to = mock('to')

    # So we can construct a range out of them...
    def from.<=>(o) 0 end
    def to.<=>(o) 0 end

    def from.to_int() 1 end
    def to.to_int() -2 end

    "hello there".slice!(from..to).should == "ello ther"

    from = mock('from')
    to = mock('to')

    def from.<=>(o) 0 end
    def to.<=>(o) 0 end

    def from.respond_to?(name) name == :to_int; end
    def from.method_missing(name) name == :to_int ? 1 : super; end
    def to.respond_to?(name) name == :to_int; end
    def to.method_missing(name) name == :to_int ? -2 : super; end

    "hello there".slice!(from..to).should == "ello ther"
  end

  it "works with Range subclasses" do
    a = "GOOD"
    range_incl = StringSpecs::MyRange.new(1, 2)

    a.slice!(range_incl).should == "OO"
  end

  ruby_version_is ""..."1.9" do
    it "raises a TypeError on a frozen instance that would be modifed" do
      lambda { "hello".freeze.slice!(1..3) }.should raise_error(TypeError)
    end

    it "does not raise an exception on a frozen instance that would not be modified" do
      "hello".freeze.slice!(10..20).should be_nil
    end
  end

  ruby_version_is "1.9" do
    it "raises a RuntimeError on a frozen instance that is modified" do
      lambda { "hello".freeze.slice!(1..3)  }.should raise_error(RuntimeError)
    end

    # see redmine #1551
    it "raises a RuntimeError on a frozen instance that would not be modified" do
      lambda { "hello".freeze.slice!(10..20)}.should raise_error(RuntimeError)
    end
  end
end

describe "String#slice! with Regexp" do
  it "deletes and returns the first match from self" do
    s = "this is a string"
    s.slice!(/s.*t/).should == 's is a st'
    s.should == 'thiring'

    c = "hello hello"
    c.slice!(/llo/).should == "llo"
    c.should == "he hello"
  end

  it "returns nil if there was no match" do
    s = "this is a string"
    s.slice!(/zzz/).should == nil
    s.should == "this is a string"
  end

  it "always taints resulting strings when self or regexp is tainted" do
    strs = ["hello world"]
    strs += strs.map { |s| s.dup.taint }

    strs.each do |str|
      str = str.dup
      str.slice!(//).tainted?.should == str.tainted?
      str.slice!(/hello/).tainted?.should == str.tainted?

      tainted_re = /./
      tainted_re.taint

      str.slice!(tainted_re).tainted?.should == true
    end
  end

  it "doesn't taint self when regexp is tainted" do
    s = "hello"
    s.slice!(/./.taint)
    s.tainted?.should == false
  end

  it "returns subclass instances" do
    s = StringSpecs::MyString.new("hello")
    s.slice!(//).should be_kind_of(StringSpecs::MyString)
    s.slice!(/../).should be_kind_of(StringSpecs::MyString)
  end

  it "sets $~ to MatchData when there is a match and nil when there's none" do
    'hello'.slice!(/./)
    $~[0].should == 'h'

    'hello'.slice!(/not/)
    $~.should == nil
  end

  ruby_version_is ""..."1.9" do
    it "raises a TypeError on a frozen instance that is modified" do
      lambda { "this is a string".freeze.slice!(/s.*t/) }.should raise_error(TypeError)
    end

    it "does not raise an exception on a frozen instance that would not be modified" do
      "this is a string".freeze.slice!(/zzz/).should be_nil
    end
  end

  ruby_version_is "1.9" do
    it "raises a RuntimeError on a frozen instance that is modified" do
      lambda { "this is a string".freeze.slice!(/s.*t/) }.should raise_error(RuntimeError)
    end

    it "raises a RuntimeError on a frozen instance that would not be modified" do
      lambda { "this is a string".freeze.slice!(/zzz/)  }.should raise_error(RuntimeError)
    end
  end
end

describe "String#slice! with Regexp, index" do
  it "deletes and returns the capture for idx from self" do
    str = "hello there"
    str.slice!(/[aeiou](.)\1/, 0).should == "ell"
    str.should == "ho there"
    str.slice!(/(t)h/, 1).should == "t"
    str.should == "ho here"
  end

  it "always taints resulting strings when self or regexp is tainted" do
    strs = ["hello world"]
    strs += strs.map { |s| s.dup.taint }

    strs.each do |str|
      str = str.dup
      str.slice!(//, 0).tainted?.should == str.tainted?
      str.slice!(/hello/, 0).tainted?.should == str.tainted?

      tainted_re = /(.)(.)(.)/
      tainted_re.taint

      str.slice!(tainted_re, 1).tainted?.should == true
    end
  end

  it "doesn't taint self when regexp is tainted" do
    s = "hello"
    s.slice!(/(.)(.)/.taint, 1)
    s.tainted?.should == false
  end

  it "returns nil if there was no match" do
    s = "this is a string"
    s.slice!(/x(zzz)/, 1).should == nil
    s.should == "this is a string"
  end

  it "returns nil if there is no capture for idx" do
    "hello there".slice!(/[aeiou](.)\1/, 2).should == nil
    # You can't refer to 0 using negative indices
    "hello there".slice!(/[aeiou](.)\1/, -2).should == nil
  end

  it "calls to_int on idx" do
    obj = mock('2')
    def obj.to_int() 2 end

    "har".slice!(/(.)(.)(.)/, 1.5).should == "h"
    "har".slice!(/(.)(.)(.)/, obj).should == "a"

    obj = mock('2')
    def obj.respond_to?(name) name == :to_int; end
    def obj.method_missing(name) name == :to_int ? 2: super; end
    "har".slice!(/(.)(.)(.)/, obj).should == "a"
  end

  it "returns subclass instances" do
    s = StringSpecs::MyString.new("hello")
    s.slice!(/(.)(.)/, 0).should be_kind_of(StringSpecs::MyString)
    s.slice!(/(.)(.)/, 1).should be_kind_of(StringSpecs::MyString)
  end

  it "sets $~ to MatchData when there is a match and nil when there's none" do
    'hello'[/.(.)/, 0]
    $~[0].should == 'he'

    'hello'[/.(.)/, 1]
    $~[1].should == 'e'

    'hello'[/not/, 0]
    $~.should == nil
  end

  ruby_version_is ""..."1.9" do 
    it "raises a TypeError if self is frozen" do
      lambda { "this is a string".freeze.slice!(/s.*t/) }.should raise_error(TypeError)
    end

    it "doesn't raise a TypeError if self is frozen but there is no match" do
      "this is a string".freeze.slice!(/zzz/, 0).should == nil
    end

    it "doesn't raise a TypeError if self is frozen but there is no capture for idx" do
      "this is a string".freeze.slice!(/(.)/, 2).should == nil
    end
  end

  ruby_version_is "1.9" do 
    it "raises a RuntimeError if self is frozen" do
      lambda { "this is a string".freeze.slice!(/s.*t/)  }.should raise_error(RuntimeError)
      lambda { "this is a string".freeze.slice!(/zzz/, 0)}.should raise_error(RuntimeError)
      lambda { "this is a string".freeze.slice!(/(.)/, 2)}.should raise_error(RuntimeError)
    end
  end
end

describe "String#slice! with String" do
  it "removes and returns the first occurrence of other_str from self" do
    c = "hello hello"
    c.slice!('llo').should == "llo"
    c.should == "he hello"
  end

  it "taints resulting strings when other is tainted" do
    strs = ["", "hello world", "hello"]
    strs += strs.map { |s| s.dup.taint }

    strs.each do |str|
      str = str.dup
      strs.each do |other|
        other = other.dup
        r = str.slice!(other)

        r.tainted?.should == !r.nil? & other.tainted?
      end
    end
  end

  it "doesn't set $~" do
    $~ = nil

    'hello'.slice!('ll')
    $~.should == nil
  end

  it "returns nil if self does not contain other" do
    a = "hello"
    a.slice!('zzz').should == nil
    a.should == "hello"
  end

  it "doesn't call to_str on its argument" do
    o = mock('x')
    o.should_not_receive(:to_str)

    lambda { "hello".slice!(o) }.should raise_error(TypeError)
  end

  it "returns a subclass instance when given a subclass instance" do
    s = StringSpecs::MyString.new("el")
    r = "hello".slice!(s)
    r.should == "el"
    r.should be_kind_of(StringSpecs::MyString)
  end

  ruby_version_is ""..."1.9" do 
    it "raises a TypeError if self is frozen" do
      lambda { "hello hello".freeze.slice!('llo') }.should raise_error(TypeError)
    end
  end

  ruby_version_is "1.9" do 
    it "raises a RuntimeError if self is frozen" do
      lambda { "hello hello".freeze.slice!('llo')     }.should raise_error(RuntimeError)
      lambda { "this is a string".freeze.slice!('zzz')}.should raise_error(RuntimeError)
      lambda { "this is a string".freeze.slice!('zzz')}.should raise_error(RuntimeError)
    end
  end
end
