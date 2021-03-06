# encoding: utf-8
require File.join(File.dirname(File.expand_path(__FILE__)), '..', '..', 'spec_helper')

describe "Retrievable" do
  
  before(:each) do
    config = Mail.defaults do
      pop3 'pop3.mockup.com', 587 do
        enable_tls
      end
    end
  end

  describe "find with and without block" do
  
    it "should find all emails with a given block" do
      MockPOP3.should_not be_started
      
      messages = []
      Mail.all do |message|
        messages << message
      end
      
      messages.map(&:raw_source).sort.should == MockPOP3.popmails.map(&:pop).sort
      MockPOP3.should_not be_started
    end
    
    it "should get all emails without a given block" do
      MockPOP3.should_not be_started
      
      messages = []
      Mail.all do |message|
        messages << message
      end
      
      messages.map(&:raw_source).sort.should == MockPOP3.popmails.map(&:pop).sort
      MockPOP3.should_not be_started
    end
  
  end

  describe "find and options" do
    
    it "should handle the :count option" do
      messages = Mail.find(:count => :all, :what => :last, :order => :asc)
      messages.map(&:raw_source).sort.should == MockPOP3.popmails.map(&:pop)
      
      message = Mail.find(:count => 1, :what => :last)
      message.raw_source.should == MockPOP3.popmails.map(&:pop).last
      
      messages = Mail.find(:count => 2, :what => :last, :order => :asc)
      messages[0..1].collect {|m| m.raw_source}.should == MockPOP3.popmails.map(&:pop)[-2..-1]
    end
    
    it "should handle the :what option" do
      messages = Mail.find(:count => :all, :what => :last)
      messages.map(&:raw_source).sort.should == MockPOP3.popmails.map(&:pop)
      
      messages = Mail.find(:count => 2, :what => :first, :order => :asc)
      messages.map(&:raw_source).should == MockPOP3.popmails.map(&:pop)[0..1]
    end
    
    it "should handle the :order option" do
      messages = Mail.find(:order => :desc, :count => 5, :what => :last)
      messages.map(&:raw_source).should == MockPOP3.popmails.map(&:pop)[-5..-1].reverse
      
      messages = Mail.find(:order => :asc, :count => 5, :what => :last)
      messages.map(&:raw_source).should == MockPOP3.popmails.map(&:pop)[-5..-1]
    end
    
    it "should find the last 10 messages by default" do
      messages = Mail.find
      
      messages.size.should == 10
    end
    
  end
  
  describe "last" do
    
    it "should find the last received messages" do
      messages = Mail.last(:count => 5)
      
      messages.should be_instance_of(Array)
      messages.map(&:raw_source).should == MockPOP3.popmails.map(&:pop)[-5..-1]
    end
    
    it "should find the last received message" do
      message = Mail.last
      
      message.should be_instance_of(Mail::Message)
      message.raw_source.should == MockPOP3.popmails.last.pop
    end
    
  end
  
  describe "first" do
    
    it "should find the first received messages" do
      messages = Mail.first(:count => 5)
      
      messages.should be_instance_of(Array)
      messages.map(&:raw_source).should == MockPOP3.popmails.map(&:pop)[0..4]
    end
    
    it "should find the first received message" do
      message = Mail.first
      
      message.should be_instance_of(Mail::Message)
      message.raw_source.should == MockPOP3.popmails.first.pop
    end
    
  end
  
  describe "all" do
    
    it "should find all messages" do
      messages = Mail.all
      
      messages.size.should == MockPOP3.popmails.size
      messages.map(&:raw_source).should == MockPOP3.popmails.map(&:pop)
    end
    
  end
  
  describe "handling of options" do
    
    it "should set default options" do
      options = Mail::POP3.validate_options({})
      
      options[:count].should be_present
      options[:count].should == 10
      
      options[:order].should be_present
      options[:order].should == :asc
      
      options[:what].should be_present
      options[:what].should == :first
    end
    
    it "should not replace given configuration" do
      options = Mail::POP3.validate_options({
        :count => 2,
        :order => :asc,
        :what => :first
      })
      
      options[:count].should be_present
      options[:count].should == 2
      
      options[:order].should be_present
      options[:order].should == :asc
      
      options[:what].should be_present
      options[:what].should == :first
    end
    
  end

  describe "error handling" do
  
    it "should finish the POP3 connection is an exception is raised" do
      MockPOP3.should_not be_started
      
      doing do
        Mail.all { |m| raise ArgumentError.new }
      end.should raise_error
      
      MockPOP3.should_not be_started
    end
    
    it "should raise if the POP3 configuration is not valid" do
      config = Mail.defaults do
        pop3 ""
      end
      
      doing { Mail.all }.should raise_error
    end
    
  end

end
