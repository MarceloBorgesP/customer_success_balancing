require 'minitest/autorun'
require 'timeout'

class CustomerSuccessBalancing
  def initialize(customer_success, customers, customer_success_away)
    @customer_success = customer_success
    @customers = customers
    @customer_success_away = customer_success_away
    @customers_unattended = @customers
  end

  def execute
    scores_count = {}
    customers_amount_for_customer_success = @customer_success
      .select { | customer_success | is_available(customer_success) }
      .sort { | a,b | (a[:score] <=> b[:score]) }
      .filter { | customer_success |
        # this logic is necessary to keep track of the repeating scores and to avoid taking too long on the next step
        scores_count[customer_success[:score]] = (scores_count[customer_success[:score]] || 0 ) + 1
        scores_count[customer_success[:score]] == 1
      }
      .to_h { |customer_success| [customer_success, count_customers_for_customer_success(customer_success) ] }

    customer_successes_with_the_most_customers = get_customer_successes_with_the_most_customers(customers_amount_for_customer_success, scores_count)
    
    customer_successes_with_the_most_customers.length == 1 ? customer_successes_with_the_most_customers[0] : 0
  end
  
  def is_available(customer_success)
    !@customer_success_away.include? customer_success[:id]
  end
  
  def count_customers_for_customer_success(customer_success)
    a, @customers_unattended = @customers_unattended.partition {|customer| customer_success[:score] >= customer[:score]}
    a.length
  end
  
  def get_customer_successes_with_the_most_customers(customers_amount_for_customer_success, scores_count)
    customer_successes_with_the_most_customers = []

    customers_amount_for_customer_success.each { | customer_success, amount |
      is_max_customers_amount = amount == customers_amount_for_customer_success.values.max
      score_doesnt_repeat = scores_count[customer_success[:score]] == 1
      
      customer_successes_with_the_most_customers << customer_success[:id] if is_max_customers_amount && score_doesnt_repeat
    }
  
    customer_successes_with_the_most_customers
  end
end

class CustomerSuccessBalancingTests < Minitest::Test
  def test_scenario_one
    css = [{ id: 1, score: 60 }, { id: 2, score: 20 }, { id: 3, score: 95 }, { id: 4, score: 75 }]
    customers = [{ id: 1, score: 90 }, { id: 2, score: 20 }, { id: 3, score: 70 }, { id: 4, score: 40 }, { id: 5, score: 60 }, { id: 6, score: 10}]

    balancer = CustomerSuccessBalancing.new(css, customers, [2, 4])
    assert_equal 1, balancer.execute
  end

  def test_scenario_two
    css = array_to_map([11, 21, 31, 3, 4, 5])
    customers = array_to_map( [10, 10, 10, 20, 20, 30, 30, 30, 20, 60])
    balancer = CustomerSuccessBalancing.new(css, customers, [])
    assert_equal 0, balancer.execute
  end

  def test_scenario_three
    customer_success = Array.new(1000, 0)
    customer_success[998] = 100

    customers = Array.new(10000, 10)
    
    balancer = CustomerSuccessBalancing.new(array_to_map(customer_success), array_to_map(customers), [1000])

    result = Timeout.timeout(1.0) { balancer.execute }
    assert_equal 999, result
  end

  def test_scenario_four
    balancer = CustomerSuccessBalancing.new(array_to_map([1, 2, 3, 4, 5, 6]), array_to_map([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]), [])
    assert_equal 0, balancer.execute
  end

  def test_scenario_five
    balancer = CustomerSuccessBalancing.new(array_to_map([100, 2, 3, 3, 4, 5]), array_to_map([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]), [])
    assert_equal balancer.execute, 1
  end

  def test_scenario_six
    balancer = CustomerSuccessBalancing.new(array_to_map([100, 99, 88, 3, 4, 5]), array_to_map([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]), [1, 3, 2])
    assert_equal balancer.execute, 0
  end

  def test_scenario_seven
    balancer = CustomerSuccessBalancing.new(array_to_map([100, 99, 88, 3, 4, 5]), array_to_map([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]), [4, 5, 6])
    assert_equal balancer.execute, 3
  end

  # The readme file states that all CSs have different levels, but test_scenario_three actually provides many CSs with the same level (0)
  # Based on that I'm creating an extra test, to make sure that in case we have a tie because of multiple CSs with the same score we also return 0
  # It also added more complexity to the solution
  def test_scenario_eight
    balancer = CustomerSuccessBalancing.new(array_to_map([3, 7, 7]), array_to_map([1, 2, 3, 4, 5, 6, 7]), [])
    assert_equal 0, balancer.execute
  end

  def array_to_map(arr)
    out = []
    arr.each_with_index { |score, index| out.push({ id: index + 1, score: score }) }
    out
  end
end

Minitest.run