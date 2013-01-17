require 'test/unit'
require 'minitest/reporters'
MiniTest::Reporters.use!

class Proc
  def call_handling(an_exception_class,&handler)
    return_continuation = proc { |an_object|
      return an_object }

    ExceptionHandler.new an_exception_class,handler,return_continuation

    call
  end
end

class ExceptionHandler


  def self.handle(an_exception)
    @current_exception_handler.handle an_exception
  end

  def handle(an_exception)
    result = if an_exception.kind_of? @exception_to_handle_class
               @handler.call an_exception
             else
               an_exception.handler_not_found
             end
    @return_continuation.call result

  end


  def self.current_exception_handler=(an_exception_handler)
    @current_exception_handler=an_exception_handler
  end

  def initialize(an_exception_class,handler,return_continuation)
    @handler = handler
    @return_continuation = return_continuation
    @exception_to_handle_class= an_exception_class
    self.class.current_exception_handler= self
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
    ExceptionHandler.handle self
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

  handler_not_found_strategy= default_handler_not_found_strategy

  def self.handler_not_found
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

  def test_4

    UnhandleException.handler_not_found_strategy= lambda { flunk }

    result = lambda {
      lambda {
        NewException.throw
        flunk }.call_handling NewExceptionSubclass do |an_exception|
        flunk
      end }.call_handling UnhandleException do |an_exception|
      2
    end

    assert_equal 2,result
  end

end