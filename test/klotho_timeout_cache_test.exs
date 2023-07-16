defmodule Klotho.TimeoutCacheTest.Timer do
  use ExUnit.Case

  alias Klotho.Support.TimeoutCache

  setup do
    {:ok, pid} = TimeoutCache.start_link()
    Klotho.Mock.reset()
    {:ok, pid: pid}
  end

  test "set and get", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar, 100)
    assert {:ok, :bar} == TimeoutCache.get(pid, :foo)
  end

  test "get after timeout", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar, 100)
    :timer.sleep(200)
    assert :not_found == TimeoutCache.get(pid, :foo)
  end

  test "renew lifetime", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar1, 100)
    :timer.sleep(50)
    TimeoutCache.set(pid, :foo, :bar2, 100)
    :timer.sleep(70)
    assert {:ok, :bar2} == TimeoutCache.get(pid, :foo)
  end
end

defmodule Klotho.TimeoutCacheTest.Klotho do
  use ExUnit.Case

  alias Klotho.Support.TimeoutCache

  setup do
    {:ok, pid} = TimeoutCache.start_link()
    Klotho.Mock.reset()
    Klotho.Mock.freeze()
    {:ok, pid: pid}
  end

  test "set and get", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar, 1000)
    assert {:ok, :bar} == TimeoutCache.get(pid, :foo)
  end

  test "get after timeout", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar, 1000)
    Klotho.Mock.warp_by(2000)
    assert :not_found == TimeoutCache.get(pid, :foo)
  end

  test "renew lifetime", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar1, 1000)
    Klotho.Mock.warp_by(500)
    TimeoutCache.set(pid, :foo, :bar2, 1000)
    Klotho.Mock.warp_by(700)
    assert {:ok, :bar2} == TimeoutCache.get(pid, :foo)
  end
end
