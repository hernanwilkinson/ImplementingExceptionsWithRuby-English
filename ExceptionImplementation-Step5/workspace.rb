
def returnFromLambda
  result = lambda { return 5 }.call
  return result + 10
end

def returnFromClosure
  result = proc { return 5 }.call
  return result + 10
end

puts returnFromLambda
puts returnFromClosure

class A
  def self.m1
    puts 1
  end

  def initialize
    self.class.m1
  end
end

A.new







