defmodule KlothoTest do
  use ExUnit.Case

  setup do
    Klotho.Mock.reset()
  end

  ########################################
  # frozen mode
  ########################################

  test "frozen mode: send_after/start_timer" do
    :ok = Klotho.Mock.freeze()
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
    :ok = Klotho.Mock.freeze()
    time = Klotho.monotonic_time(:millisecond)
    Klotho.Mock.warp_by(100)
    assert Klotho.monotonic_time(:millisecond) == time + 100
  end

  test "frozen mode: cancel timer" do
    :ok = Klotho.Mock.freeze()
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
    :ok = Klotho.Mock.freeze()
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
    :ok = Klotho.Mock.freeze()
    assert :ok == Klotho.Mock.freeze()
  end

  test "frozen mode: cancel ref" do
    :ok = Klotho.Mock.freeze()
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
    :ok = Klotho.Mock.freeze()
    assert false == Klotho.cancel_timer(make_ref())

    ref = Klotho.send_after(100, self(), "test")
    Klotho.Mock.warp_by(50)

    left = Klotho.read_timer(ref)
    assert is_integer(left)
    assert left <= 50

    Klotho.Mock.warp_by(50)

    assert_receive "test"
  end

  test "frozen mode: system_time" do
    :ok = Klotho.Mock.freeze()
    t0 = Klotho.system_time(:millisecond)

    Klotho.Mock.warp_by(1000)
    t1 = :erlang.convert_time_unit(Klotho.system_time(), :native, :millisecond)

    assert t1 - t0 >= 1000
  end

  test "frozen mode: time_offset" do
    :ok = Klotho.Mock.freeze()

    assert_in_delta Klotho.monotonic_time(:millisecond) + Klotho.time_offset(:millisecond),
                    Klotho.system_time(:millisecond),
                    10

    Klotho.Mock.warp_by(1000)

    assert_in_delta Klotho.monotonic_time(:millisecond) +
                      :erlang.convert_time_unit(Klotho.time_offset(), :native, :millisecond),
                    Klotho.system_time(:millisecond),
                    10
  end

  test "frozen mode: send_ater/start_timer absolute" do
    :ok = Klotho.Mock.freeze()
    t = Klotho.monotonic_time(:millisecond)
    Klotho.send_after(t + 100, self(), "hello", abs: true)
    ref = Klotho.start_timer(t + 200, self(), "world", abs: true)
    Klotho.Mock.warp_by(99)
    refute_received "hello"
    Klotho.Mock.warp_by(2)
    assert_receive "hello"
    refute_received {:timeout, ^ref, "world"}
    Klotho.Mock.warp_by(100)
    assert_receive {:timeout, ^ref, "world"}
  end

  test "frozen: cancel" do
    :ok = Klotho.Mock.freeze()
    ref0 = Klotho.send_after(50, self(), "hello")
    ref1 = Klotho.send_after(150, self(), "whole")
    ref2 = Klotho.send_after(250, self(), "world")
    ref3 = Klotho.send_after(300, self(), "!!")
    ref4 = make_ref()

    assert :ok == Klotho.cancel_timer(ref0, info: false, async: true)
    assert :ok == Klotho.cancel_timer(ref1, info: false, async: false)
    assert_in_delta 250, Klotho.cancel_timer(ref2, info: true, async: false), 20
    Klotho.cancel_timer(ref3, info: true, async: true)
    Klotho.cancel_timer(ref4, info: true, async: true)

    Klotho.Mock.warp_by(300)
    refute_receive "!!"
    refute_receive "world"
    refute_receive "whole"
    refute_receive "hello"
    assert_receive {:cancel_timer, ^ref3, _}
    assert_receive {:cancel_timer, ^ref4, false}
  end

  ########################################################
  # running mode
  ########################################################

  test "running mode: monotonic_time" do
    time = Klotho.monotonic_time(:millisecond)
    :timer.sleep(5)
    assert Klotho.monotonic_time(:millisecond) >= time + 5
  end

  test "running mode: warp_by" do
    time = Klotho.monotonic_time(:millisecond)
    Klotho.Mock.warp_by(100)
    assert Klotho.monotonic_time(:millisecond) >= time + 100
  end

  test "running mode: send_after/start_timer" do
    Klotho.send_after(50, self(), "hello")
    ref = Klotho.start_timer(150, self(), "world")
    Klotho.send_after(250, self(), "!!")

    t1 = Klotho.monotonic_time(:millisecond)

    :timer.sleep(100)
    # because time is running
    assert_receive "hello"
    refute_received {:timeout, ^ref, "world"}

    Klotho.Mock.warp_by(100)
    # because time is warped by 100ms, 200ms now "passed"
    assert_receive {:timeout, ^ref, "world"}
    refute_received "!!"

    :timer.sleep(100)

    # because time is warped by 100ms, 300ms now "passed"
    assert_receive "!!"

    t2 = Klotho.monotonic_time(:millisecond)

    assert t2 >= t1 + 300
  end

  test "running: cancel" do
    ref0 = Klotho.send_after(50, self(), "hello")
    ref1 = Klotho.send_after(150, self(), "whole")
    ref2 = Klotho.send_after(250, self(), "world")
    ref3 = Klotho.send_after(300, self(), "!!")
    ref4 = make_ref()

    assert :ok == Klotho.cancel_timer(ref0, info: false, async: true)
    assert :ok == Klotho.cancel_timer(ref1, info: false, async: false)
    assert_in_delta 250, Klotho.cancel_timer(ref2, info: true, async: false), 20
    Klotho.cancel_timer(ref3, info: true, async: true)
    Klotho.cancel_timer(ref4, info: true, async: true)

    Klotho.Mock.warp_by(300)
    refute_receive "!!"
    refute_receive "world"
    refute_receive "whole"
    refute_receive "hello"
    assert_receive {:cancel_timer, ^ref3, _}
    assert_receive {:cancel_timer, ^ref4, false}
  end

  test "running mode: freeze/unfreeze" do
    t1 = Klotho.monotonic_time()
    :timer.sleep(1)
    # unfreeze is a noop in running mode
    assert :ok == Klotho.Mock.unfreeze()
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
    assert false == Klotho.cancel_timer(make_ref())

    ref = Klotho.send_after(100, self(), "test")
    Klotho.Mock.warp_by(50)

    left = Klotho.read_timer(ref)
    assert is_integer(left)
    assert left <= 50

    Klotho.Mock.warp_by(50)

    assert_receive "test"
  end

  test "running mode: system_time" do
    t0 = Klotho.system_time(:millisecond)

    Klotho.Mock.warp_by(500)
    :timer.sleep(100)
    t1 = :erlang.convert_time_unit(Klotho.system_time(), :native, :millisecond)

    assert t1 - t0 >= 600
  end

  test "running mode: time_offset" do
    assert_in_delta Klotho.monotonic_time(:millisecond) + Klotho.time_offset(:millisecond),
                    Klotho.system_time(:millisecond),
                    10

    Klotho.Mock.warp_by(500)
    :timer.sleep(100)

    assert_in_delta Klotho.monotonic_time(:millisecond) +
                      :erlang.convert_time_unit(Klotho.time_offset(), :native, :millisecond),
                    Klotho.system_time(:millisecond),
                    10
  end

  test "running mode: send_after/start_timer absolute" do
    t = Klotho.monotonic_time(:millisecond)
    Klotho.send_after(t + 50, self(), "hello", abs: true)
    ref = Klotho.start_timer(t + 150, self(), "world", abs: true)
    Klotho.send_after(t + 250, self(), "!!", abs: true)

    t1 = Klotho.monotonic_time(:millisecond)

    :timer.sleep(100)
    # because time is running
    assert_receive "hello"
    refute_received {:timeout, ^ref, "world"}

    Klotho.Mock.warp_by(100)
    # because time is warped by 100ms, 200ms now "passed"
    assert_receive {:timeout, ^ref, "world"}
    refute_received "!!"

    :timer.sleep(100)

    # because time is warped by 100ms, 300ms now "passed"
    assert_receive "!!"

    t2 = Klotho.monotonic_time(:millisecond)

    assert t2 >= t1 + 300
  end

  ######################################################################
  # common tests
  ######################################################################

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

    Klotho.Real.send_after(:erlang.monotonic_time(:millisecond), self(), "world abs", abs: true)
    assert_receive "world abs"

    ref = Klotho.Real.start_timer(0, self(), "!!")
    assert_receive {:timeout, ^ref, "!!"}

    ref =
      Klotho.Real.start_timer(:erlang.monotonic_time(:millisecond), self(), "!! abs", abs: true)

    assert_receive {:timeout, ^ref, "!! abs"}

    t1 = Klotho.Real.system_time(:millisecond)
    :timer.sleep(1)
    t2 = Klotho.Real.system_time(:millisecond)
    assert t1 < t2

    t3 = Klotho.Real.system_time()
    :timer.sleep(1)
    t4 = Klotho.Real.system_time()
    assert t3 < t4

    assert_in_delta Klotho.Real.monotonic_time(:millisecond) +
                      :erlang.convert_time_unit(Klotho.Real.time_offset(), :native, :millisecond),
                    Klotho.Real.system_time(:millisecond),
                    10

    assert_in_delta Klotho.Real.monotonic_time(:millisecond) +
                      Klotho.Real.time_offset(:millisecond),
                    Klotho.Real.system_time(:millisecond),
                    10
  end

  test "history" do
    Klotho.send_after(50, self(), "hello")
    Klotho.start_timer(150, self(), "world")

    Klotho.Mock.warp_by(200)

    history = Klotho.Mock.timer_event_history()

    assert [
             %Klotho.Mock.TimerMsg{message: "world", type: :start_timer},
             %Klotho.Mock.TimerMsg{message: "hello", type: :send_after}
           ] = history

    Klotho.Mock.reset()

    assert [] = Klotho.Mock.timer_event_history()
  end
end
