defmodule KlothoTest do
  use ExUnit.Case

  test "frozen mode: send_after/start_timer" do
    {:ok, _} = Klotho.Mock.start_link(:frozen)
    Klotho.send_after(100, self(), "hello")
    ref = Klotho.start_timer(200, self(), "world")
    Klotho.Mock.warp_by(99)
    refute_received "hello"
    Klotho.Mock.warp_by(2)
    assert_receive "hello"
    refute_received {:timeout, ^ref, "world"}
    Klotho.Mock.warp_by(100)
    assert_receive {:timeout, ^ref, "world"}
  end

  test "frozen mode: monotonic_time" do
    {:ok, _} = Klotho.Mock.start_link(:frozen)
    time = Klotho.monotonic_time(:millisecond)
    Klotho.Mock.warp_by(100)
    assert Klotho.monotonic_time(:millisecond) == time + 100
  end

  test "frozen mode: cancel timer" do
    {:ok, _} = Klotho.Mock.start_link(:frozen)
    _ref0 = Klotho.send_after(100, self(), "hello")
    ref1 = Klotho.send_after(200, self(), "world")
    _ref2 = Klotho.send_after(300, self(), "!!")
    Klotho.cancel_timer(ref1)
    Klotho.Mock.warp_by(101)
    assert_receive "hello"
    Klotho.Mock.warp_by(200)
    refute_receive "world"
    assert_receive "!!"
  end

  test "frozen mode: unfreeze" do
    {:ok, _} = Klotho.Mock.start_link(:frozen)
    t1 = Klotho.monotonic_time()
    :timer.sleep(1)
    t2 = Klotho.monotonic_time()
    Klotho.Mock.unfreeze()
    :timer.sleep(1)
    t3 = Klotho.monotonic_time()

    assert t1 == t2
    assert t2 < t3
  end

  test "frozen mode: freeze" do
    {:ok, _} = Klotho.Mock.start_link(:frozen)
    assert :ok == Klotho.Mock.freeze()
  end

  test "frozen mode: cancel ref" do
    {:ok, _} = Klotho.Mock.start_link(:frozen)
    assert false == Klotho.cancel_timer(make_ref())

    ref = Klotho.send_after(100, self(), "test")
    Klotho.Mock.warp_by(50)

    left = Klotho.cancel_timer(ref)
    assert is_integer(left)
    assert left <= 50

    Klotho.Mock.warp_by(50)

    refute_receive "test"
  end

  test "frozen mode: read ref" do
    {:ok, _} = Klotho.Mock.start_link(:frozen)
    assert false == Klotho.cancel_timer(make_ref())

    ref = Klotho.send_after(100, self(), "test")
    Klotho.Mock.warp_by(50)

    left = Klotho.read_timer(ref)
    assert is_integer(left)
    assert left <= 50

    Klotho.Mock.warp_by(50)

    assert_receive "test"
  end

  test "running mode: monotonic_time" do
    {:ok, _} = Klotho.Mock.start_link()
    time = Klotho.monotonic_time(:millisecond)
    :timer.sleep(5)
    assert Klotho.monotonic_time(:millisecond) >= time + 5
  end

  test "running mode: warp_by" do
    {:ok, _} = Klotho.Mock.start_link()
    time = Klotho.monotonic_time(:millisecond)
    Klotho.Mock.warp_by(100)
    assert Klotho.monotonic_time(:millisecond) >= time + 100
  end

  test "running mode: send_after/start_timer" do
    {:ok, _} = Klotho.Mock.start_link()
    Klotho.send_after(50, self(), "hello")
    ref = Klotho.start_timer(150, self(), "world")
    Klotho.send_after(250, self(), "!!")

    t1 = Klotho.monotonic_time(:millisecond)

    :timer.sleep(100)
    assert_receive "hello" # because time is running
    refute_received {:timeout, ^ref, "world"}

    Klotho.Mock.warp_by(100)
    assert_receive {:timeout, ^ref, "world"} # because time is warped by 100ms, 200ms now "passed"
    refute_received "!!"

    :timer.sleep(100)

    assert_receive "!!" # because time is warped by 100ms, 300ms now "passed"

    t2 = Klotho.monotonic_time(:millisecond)

    assert t2 >= t1 + 300
  end

  test "running: cancel" do
    {:ok, _} = Klotho.Mock.start_link()
    ref0 = Klotho.send_after(50, self(), "hello")
    ref1 = Klotho.send_after(150, self(), "world")
    _ref2 = Klotho.send_after(250, self(), "!!")

    Klotho.cancel_timer(ref1)
    Klotho.cancel_timer(ref0)

    Klotho.Mock.warp_by(300)
    assert_received "!!"
    refute_received "world"
    refute_received "hello"
  end

  test "running mode: freeze/unfreeze" do
    {:ok, _} = Klotho.Mock.start_link()
    t1 = Klotho.monotonic_time()
    :timer.sleep(1)
    assert :ok == Klotho.Mock.unfreeze() # unfreeze is a noop in running mode
    Klotho.Mock.freeze()
    t2 = Klotho.monotonic_time()
    :timer.sleep(1)
    t3 = Klotho.monotonic_time()
    Klotho.Mock.unfreeze()
    :timer.sleep(1)
    t4 = Klotho.monotonic_time()

    assert t1 < t2
    assert t2 == t3
    assert t3 < t4
  end

  test "running mode: cancel ref" do
    {:ok, _} = Klotho.Mock.start_link()
    assert false == Klotho.cancel_timer(make_ref())

    ref = Klotho.send_after(100, self(), "test")
    Klotho.Mock.warp_by(50)

    left = Klotho.cancel_timer(ref)
    assert is_integer(left)
    assert left <= 50

    Klotho.Mock.warp_by(50)

    refute_receive "test"
  end

  test "running mode: read ref" do
    {:ok, _} = Klotho.Mock.start_link()
    assert false == Klotho.cancel_timer(make_ref())

    ref = Klotho.send_after(100, self(), "test")
    Klotho.Mock.warp_by(50)

    left = Klotho.read_timer(ref)
    assert is_integer(left)
    assert left <= 50

    Klotho.Mock.warp_by(50)

    assert_receive "test"
  end

  test "real implementation" do
    t1 = Klotho.Real.monotonic_time(:millisecond)
    :timer.sleep(1)
    t2 = Klotho.Real.monotonic_time(:millisecond)
    assert t1 < t2

    t3 = Klotho.Real.monotonic_time()
    :timer.sleep(1)
    t4 = Klotho.Real.monotonic_time()
    assert t3 < t4

    ref = Klotho.Real.send_after(100, self(), "hello")
    assert Klotho.Real.read_timer(ref) <= 100
    assert Klotho.Real.cancel_timer(ref) <= 100

    Klotho.Real.send_after(0, self(), "world")
    assert_receive "world"

    ref = Klotho.Real.start_timer(0, self(), "!!")
    assert_receive {:timeout, ^ref, "!!"}

  end
end
