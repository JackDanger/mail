#!ruby19
# encoding: utf-8

require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

# Require ActiveSupport for multibyte strings
begin
  require 'active_support'
rescue
  gem 'activesupport'
  require 'active_support'
end

module MultibyteCharsSpec
  describe "an anything symbol" do
    testing_expression '.'
    it "matches an UTF-8 character" do
      parse_multibyte("ø").should_not be_nil
    end
  end
  
  describe "A character class containing UTF-8 characters" do
    testing_expression "[æøå]"
    it "recognizes the UTF-8 characters" do
      parse_multibyte("ø").should_not be_nil
    end
  end
  
  describe "a character class repetition containing UTF-8 characters mixed with other expressions" do
    testing_expression '[æøå]+ "a"'
    it "lazily instantiates a node for the character" do
      result = parse_multibyte('æøåa')
      pending "Multibyte support is not supported in Ruby 1.8.6" if RUBY_VERSION =~ /^1\.8.6/
      result.elements[0].instance_variable_get("@elements").should include(true)
      result.elements[0].elements.should_not include(true)
      result.elements[0].elements.size.should == 3
      result.elements.size.should == 2
      result.elements[0].text_value.should == "æøå"
      result.elements[0].elements[0].text_value.should == "æ"
      result.elements[0].elements[1].text_value.should == "ø"
      result.elements[0].elements[2].text_value.should == "å"
      result.elements[1].text_value == "a"
    end
  end
  
end
