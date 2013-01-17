require 'test/unit'
require 'minitest/reporters'
MiniTest::Reporters.use!

class Proc
  def call_handling(an_exception_class,&handler)
    condition = lambda { |an_exception| an_exception_class.handles? an_exception }
    call_handling_when condition,&handler
  end

  def call_handling_when(a_condition,&handler)
    return_continuation = proc { |an_object|
      return an_object }

    DefinedExceptionHandler.install_new_handler_while_evaluating self,a_condition,handler,return_continuation

  end
end

class ExceptionHandler
  def handle(an_exception)
    #should implement by subclass
    fail
  end
end

class UndefinedExceptionHandler < ExceptionHandler
  def handle(an_exception)
    an_exception.handler_not_found
  end
end

class DefinedExceptionHandler < ExceptionHandler

  def self.last_handler=(a_handler)
    Thread.current[:last_handler]=a_handler
  end

  def self.last_handler
    Thread.current[:last_handler] ||= initialize_last_handler
  end

  def self.initialize_last_handler
    self.last_handler= UndefinedExceptionHandler.new
  end

  def self.install_new_handler_while_evaluating(a_block,a_condition,handler,return_continuation)
    self.last_handler= self.new a_condition,handler,return_continuation,self.last_handler

    begin
      a_block.call
    ensure
      uninstall
    end

  end

  def previous
    @previous
  end

  def self.handle(an_exception)
    self.last_handler.handle an_exception
  end

  def handle(an_exception)
    result = if should_handle an_exception
               @handler.call an_exception
             else
               @previous.handle an_exception
             end
    @return_continuation.call result

  end

  def should_handle(an_exception)
    @condition.call an_exception
  end


  def initialize(a_condition,handler,return_continuation,previous)
    @handler = handler
    @return_continuation = return_continuation
    @condition= a_condition
    @previous = previous
  end

  private
  def self.uninstall
    self.last_handler= self.last_handler.previous
  end

end

class ExceptionHierarchyFilter
  def initialize(hierarchy_root,a_subclass_to_filter)
    @hierarchy_root = hierarchy_root
    @subclass_to_filter = a_subclass_to_filter
  end

  def handles?(an_exception)
    if an_exception.class==@subclass_to_filter
      false
    else
      @hierarchy_root.handles? an_exception
    end
  end
end

class NewException
  def description
    @description
  end

  def self.handles?(an_exception)
    an_exception.kind_of? self
  end

  def self.but(a_subclass)
    ExceptionHierarchyFilter.new self,a_subclass
  end

  def handler_not_found
    UnhandleException.throw
  end

  def self.throw(description='')
    self.new(description).throw
  end

  def initialize(description)
    @description=description
  end

  def throw
    DefinedExceptionHandler.handle self
  end
end

class NewExceptionSubclass < NewException

end

class UnhandleException < NewException
  def self.handler_not_found_strategy=(an_strategy)
    Thread.current[:handler_not_found_strategy] = an_strategy
  end

  def self.handler_not_found_strategy
    Thread.current[:handler_not_found_strategy] ||= default_handler_not_found_strategy
  end

  def self.default_handler_not_found_strategy
    proc { exit -1 }
  end

  def self.handler_not_found
    self.handler_not_found_strategy.call
  end

  def handler_not_found
    self.class.handler_not_found
  end
end

class AnotherNewExceptionSubclass < NewException
end

class ExceptionImplementationTest < Test::Unit::TestCase

  def test_when_no_exception_is_thrown_it_handler_is_not_evaluated

    result = lambda { 1+1 }.call_handling Exception do |an_exception|
      flunk
    end

    assert_equal 2,result
  end

  def test_when_an_exception_is_thrown_its_handler_is_evaluated

    result = lambda {
      NewException.throw
      flunk }.call_handling NewException do |an_exception|
      2
    end

    assert_equal 2,result
  end

  def test_when_an_exception_is_not_handle_then_handler_not_found_strategy_is_evaluated

    UnhandleException.handler_not_found_strategy= lambda { 'Handler not found' }

    result = lambda {
      NewException.throw
      flunk }.call_handling NewExceptionSubclass do |an_exception|
      flunk
    end

    assert_equal 'Handler not found',result
  end

  def test_nested_handlers_are_supported

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

  def test_1

    handler_evaluated = lambda { NewExceptionSubclass.throw }.call_handling NewException.but AnotherNewExceptionSubclass do
      |an_exception|
      true
    end

    assert handler_evaluated
  end

  def test_2

    handler_evaluated = lambda {
      lambda { NewExceptionSubclass.throw }.call_handling NewException.but NewExceptionSubclass do
      |an_exception|
        false
      end }.call_handling NewExceptionSubclass do |an_exception|
      true
    end

    assert handler_evaluated
  end

  def test_3

    handler_evaluated = lambda { NewException.throw 'Some description' }.call_handling_when lambda {
        |an_exception | an_exception.description=='Some description' } do
      true
    end

    assert handler_evaluated
  end

  def test_4

    handler_evaluated = lambda {
      lambda { NewException.throw 'Some description' }.call_handling_when lambda {
          |an_exception | an_exception.description=='xxx' } do
        false
      end }.call_handling_when lambda { |an_exception| an_exception.description=='Some description'} do
      |an_exception|
      true
    end

    assert handler_evaluated
  end

  def test_5
    in_call_handling_thread_1 = false
    in_call_handling_thread_2 = false

    thread_1_result = 0
    thread_2_result = 0

    thread_2 = nil

    thread_1 = Thread.new do
      thread_1_result = lambda {
        in_call_handling_thread_1 = true
        Thread.pass while !in_call_handling_thread_2
        NewException.throw }.call_handling NewException do |an_exception | 1 end
      thread_2.run
    end

    thread_2 = Thread.new do
      Thread.pass while !in_call_handling_thread_1
      thread_2_result = lambda {
        in_call_handling_thread_2 = true
        Thread.stop
        NewException.throw }.call_handling NewException do |an_exception | 2 end
    end

    thread_1.join
    thread_2.join

    assert_equal 1, thread_1_result
    assert_equal 2, thread_2_result
  end

  def test_6

    thread_1_result = 0
    thread_2_result = 0

    handler_not_fount_strategy_set_thread_1 = false
    handler_not_fount_strategy_set_thread_2 = false

    thread_2 = nil

    thread_1 = Thread.new do
      UnhandleException.handler_not_found_strategy= lambda { 1 }
      handler_not_fount_strategy_set_thread_1 = true
      Thread.pass while !handler_not_fount_strategy_set_thread_2
      thread_1_result = NewException.throw
      thread_2.run
    end

    thread_2 = Thread.new do
      Thread.pass while !handler_not_fount_strategy_set_thread_1
      UnhandleException.handler_not_found_strategy= lambda { 2 }
      handler_not_fount_strategy_set_thread_2 = true
      Thread.stop
      thread_2_result = NewException.throw
    end

    thread_1.join
    thread_2.join

    assert_equal 1, thread_1_result
    assert_equal 2, thread_2_result

  end
end