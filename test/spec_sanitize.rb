#--
# Copyright (c) 2009 Ryan Grove <ryan@wonko.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#++

require 'rubygems'
require 'bacon'

require File.join(File.dirname(__FILE__), '../lib/sanitize')

strings = {
  :basic => {
    :html       => '<b>Lo<!-- comment -->rem</b> <a href="pants" title="foo">ipsum</a> <a href="http://foo.com/"><strong>dolor</strong></a> sit<br/>amet <script>alert("hello world");</script>',
    :default    => 'Lorem ipsum dolor sitamet alert(&quot;hello world&quot;);',
    :restricted => '<b>Lorem</b> ipsum <strong>dolor</strong> sitamet alert(&quot;hello world&quot;);',
    :basic      => '<b>Lorem</b> <a href="pants" rel="nofollow">ipsum</a> <a href="http://foo.com/" rel="nofollow"><strong>dolor</strong></a> sit<br />amet alert(&quot;hello world&quot;);',
    :relaxed    => '<b>Lorem</b> <a href="pants" title="foo">ipsum</a> <a href="http://foo.com/"><strong>dolor</strong></a> sit<br />amet alert(&quot;hello world&quot;);'
  },

  :malformed => {
    :html       => 'Lo<!-- comment -->rem</b> <a href=pants title="foo>ipsum <a href="http://foo.com/"><strong>dolor</a></strong> sit<br/>amet <script>alert("hello world");',
    :default    => 'Lorem &lt;a href=pants title=&quot;foo&gt;ipsum dolor sitamet alert(&quot;hello world&quot;);',
    :restricted => 'Lorem &lt;a href=pants title=&quot;foo&gt;ipsum <strong>dolor</strong> sitamet alert(&quot;hello world&quot;);',
    :basic      => 'Lorem &lt;a href=pants title=&quot;foo&gt;ipsum <a href="http://foo.com/" rel="nofollow"><strong>dolor</strong></a> sit<br />amet alert(&quot;hello world&quot;);',
    :relaxed    => 'Lorem &lt;a href=pants title=&quot;foo&gt;ipsum <a href="http://foo.com/"><strong>dolor</strong></a> sit<br />amet alert(&quot;hello world&quot;);'
  },

  :malicious => {
    :html       => '<b>Lo<!-- comment -->rem</b> <a href="javascript:pants" title="foo">ipsum</a> <a href="http://foo.com/"><strong>dolor</strong></a> sit<br/>amet <<foo>script>alert("hello world");</script>',
    :default    => 'Lorem ipsum dolor sitamet &lt;script&gt;alert(&quot;hello world&quot;);',
    :restricted => '<b>Lorem</b> ipsum <strong>dolor</strong> sitamet &lt;script&gt;alert(&quot;hello world&quot;);',
    :basic      => '<b>Lorem</b> <a rel="nofollow">ipsum</a> <a href="http://foo.com/" rel="nofollow"><strong>dolor</strong></a> sit<br />amet &lt;script&gt;alert(&quot;hello world&quot;);',
    :relaxed    => '<b>Lorem</b> <a title="foo">ipsum</a> <a href="http://foo.com/"><strong>dolor</strong></a> sit<br />amet &lt;script&gt;alert(&quot;hello world&quot;);'
  },

  :raw_comment => {
    :html       => '<!-- comment -->Hello',
    :default    => 'Hello',
    :restricted => 'Hello',
    :basic      => 'Hello',
    :relaxed    => 'Hello'
  }
}

tricky = {
  'protocol-based JS injection: UTF-8 encoding' => {
    :html       => '<a href="javascript&#58;">foo</a>',
    :default    => 'foo',
    :restricted => 'foo',
    :basic      => '<a rel="nofollow">foo</a>',
    :relaxed    => '<a>foo</a>'
  },

  'protocol-based JS injection: long UTF-8 encoding' => {
    :html       => '<a href="javascript&#0058;">foo</a>',
    :default    => 'foo',
    :restricted => 'foo',
    :basic      => '<a rel="nofollow">foo</a>',
    :relaxed    => '<a>foo</a>'
  },

  'protocol-based JS injection: long UTF-8 encoding without semicolons' => {
    :html       => '<a href=&#0000106&#0000097&#0000118&#0000097&#0000115&#0000099&#0000114&#0000105&#0000112&#0000116&#0000058&#0000097&#0000108&#0000101&#0000114&#0000116&#0000040&#0000039&#0000088&#0000083&#0000083&#0000039&#0000041>foo</a>',
    :default    => 'foo',
    :restricted => 'foo',
    :basic      => '<a rel="nofollow">foo</a>',
    :relaxed    => '<a>foo</a>'
  },

  'protocol-based JS injection: hex encoding' => {
    :html       => '<a href="javascript&#x3A;">foo</a>',
    :default    => 'foo',
    :restricted => 'foo',
    :basic      => '<a rel="nofollow">foo</a>',
    :relaxed    => '<a>foo</a>'
  },

  'protocol-based JS injection: long hex encoding' => {
    :html       => '<a href="javascript&#x003A;">foo</a>',
    :default    => 'foo',
    :restricted => 'foo',
    :basic      => '<a rel="nofollow">foo</a>',
    :relaxed    => '<a>foo</a>'
  },

  'protocol-based JS injection: hex encoding without semicolons' => {
    :html       => '<a href=&#x6A&#x61&#x76&#x61&#x73&#x63&#x72&#x69&#x70&#x74&#x3A&#x61&#x6C&#x65&#x72&#x74&#x28&#x27&#x58&#x53&#x53&#x27&#x29>foo</a>',
    :default    => 'foo',
    :restricted => 'foo',
    :basic      => '<a rel="nofollow">foo</a>',
    :relaxed    => '<a>foo</a>'
  }
}

describe 'Config::DEFAULT' do
  should 'preserve valid HTML entities' do
    Sanitize.clean("Don&apos;t tas&eacute; me &amp; bro!").should.equal("Don&apos;t tas&eacute; me &amp; bro!")
  end

  should 'not choke on several instances of the same element in a row' do
    Sanitize.clean('<img src="http://www.google.com/intl/en_ALL/images/logo.gif"><img src="http://www.google.com/intl/en_ALL/images/logo.gif"><img src="http://www.google.com/intl/en_ALL/images/logo.gif"><img src="http://www.google.com/intl/en_ALL/images/logo.gif">').should.equal('')
  end

  strings.each do |name, data|
    should "clean #{name} HTML" do
      Sanitize.clean(data[:html]).should.equal(data[:default])
    end
  end

  tricky.each do |name, data|
    should "not allow #{name}" do
      Sanitize.clean(data[:html]).should.equal(data[:default])
    end
  end
end

describe 'Config::RESTRICTED' do
  before { @s = Sanitize.new(Sanitize::Config::RESTRICTED) }

  strings.each do |name, data|
    should "clean #{name} HTML" do
      @s.clean(data[:html]).should.equal(data[:restricted])
    end
  end

  tricky.each do |name, data|
    should "not allow #{name}" do
      @s.clean(data[:html]).should.equal(data[:restricted])
    end
  end
end

describe 'Config::BASIC' do
  before { @s = Sanitize.new(Sanitize::Config::BASIC) }

  should 'not choke on valueless attributes' do
    @s.clean('foo <a href>foo</a> bar').should.equal('foo <a rel="nofollow">foo</a> bar')
  end

  strings.each do |name, data|
    should "clean #{name} HTML" do
      @s.clean(data[:html]).should.equal(data[:basic])
    end
  end

  tricky.each do |name, data|
    should "not allow #{name}" do
      @s.clean(data[:html]).should.equal(data[:basic])
    end
  end
end

describe 'Config::RELAXED' do
  before { @s = Sanitize.new(Sanitize::Config::RELAXED) }

  strings.each do |name, data|
    should "clean #{name} HTML" do
      @s.clean(data[:html]).should.equal(data[:relaxed])
    end
  end

  tricky.each do |name, data|
    should "not allow #{name}" do
      @s.clean(data[:html]).should.equal(data[:relaxed])
    end
  end
end

describe 'Sanitize.clean' do
  should 'not modify the input string' do
    input = '<b>foo</b>'
    Sanitize.clean(input)
    input.should.equal('<b>foo</b>')
  end

  should 'return the modified string' do
    input = '<b>foo</b>'
    Sanitize.clean(input).should.equal('foo')
  end
end

describe 'Sanitize.clean!' do
  should 'modify the input string' do
    input = '<b>foo</b>'
    Sanitize.clean!(input)
    input.should.equal('foo')
  end

  should 'return the new string if it was modified' do
    input = '<b>foo</b>'
    Sanitize.clean!(input).should.equal('foo')
  end

  should 'return nil if the string was not modified' do
    input = 'foo'
    Sanitize.clean!(input).should.equal(nil)
  end
end
