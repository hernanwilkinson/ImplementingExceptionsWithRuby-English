require 'test/unit'
require 'minitest/reporters'
MiniTest::Reporters.use!

class Proc
  def self.current_handler=(handler)
    @current_handler = handler
  end

  def self.handle(an_exception)
    if an_exception.kind_of? @exception_to_handle_class
      result = @current_handler.call an_exception
      @return_closure.call result
    else
      @return_closure.call an_exception.handler_not_found
    end
  end

  def self.return_closure=(return_closure)
    @return_closure = return_closure
  end

  def self.exception_to_handle_class=(an_exception_class)
    @exception_to_handle_class=an_exception_class
  end

  def call_handling(an_exception_class,&handler)
    self.class.current_handler= handler
    self.class.return_closure= proc { |an_object|
      return an_object }
    self.class.exception_to_handle_class= an_exception_class

    call
  end
end

class NewException
  def handler_not_found
    UnhandleException.throw
  end

  def self.throw
    self.new.throw
  end

  def throw
    Proc.handle self
  end
end

class NewExceptionSubclass < NewException

end

class UnhandleException < NewException
  def self.handler_not_found_strategy=(an_strategy)
    @handler_not_found_strategy = an_strategy
  end

  def self.default_handler_not_found_strategy
    proc { exit -1 }
  end

  def self.handler_not_found
    @handler_not_found_strategy ||= default_handler_not_found_strategy
    @handler_not_found_strategy.call
  end

  def handler_not_found
    self.class.handler_not_found
  end
end

class ExceptionImplementationTest < Test::Unit::TestCase

  def test_1

    result = lambda { 1+1 }.call_handling Exception do |an_exception|
      flunk
    end

    assert_equal 2,result
  end

  def test_2

    result = lambda {
      NewException.throw
      flunk }.call_handling NewException do |an_exception|
      2
    end

    assert_equal 2,result
  end

  def test_3

    UnhandleException.handler_not_found_strategy= lambda { 'Handler not found' }

    result = lambda {
      NewException.throw
      flunk }.call_handling NewExceptionSubclass do |an_exception|
      flunk
    end

    assert_equal 'Handler not found',result
  end

end