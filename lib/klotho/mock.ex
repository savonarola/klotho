defmodule Klotho.Mock do
  @moduledoc """
  This is the backend is used in `:test` environment.

  The module gives control of the mocked time and provides inspection
  of triggered timers.
  """

  @server __MODULE__
  @behaviour :gen_statem

  @doc false
  defguard is_non_negative_integer(x) when is_integer(x) and x >= 0

  @doc false
  defguard is_reciever(x) when is_pid(x) or is_atom(x)

  defmodule TimerMsg do
    @moduledoc """
    Struct to represent a timer message.
    """
    defstruct [:pid, :time, :message, :ref, :type]

    @type t :: %__MODULE__{
            pid: pid(),
            time: non_neg_integer(),
            message: term(),
            ref: reference(),
            type: :send_after | :start_timer
          }
  end

  # to have `%Data{}` for `:gen_statem`'s `Data`
  alias __MODULE__, as: Data

  defstruct time: 0,
            unfreeze_time: 0,
            timer_messages: [],
            timer_message_history: [],
            start_time: 0,
            start_system_time: 0

  # Internal API

  @doc false
  def start_link(state) when state == :running or state == :frozen do
    :gen_statem.start_link({:local, @server}, __MODULE__, [state], [])
  end

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  # External API

  @doc """
  Warp time forward by `timer_interval` milliseconds.
  Regardless of the current mode (frozen or running), all the timers
  that are due to trigger within the next `timer_interval` milliseconds
  will be triggered after warp.
  """

  @spec warp_by(non_neg_integer) :: :ok
  def warp_by(timer_interval) do
    warp_by(timer_interval, :millisecond)
  end

  @doc """
  Warp time forward by `timer_interval` in `unit`.
  Regardless of the current mode (frozen or running), all the timers
  that are due to trigger within the next `timer_interval` milliseconds
  will be triggered after warp.
  """

  @spec warp_by(non_neg_integer, :erlang.time_unit()) :: :ok
  def warp_by(timer_interval, unit) when timer_interval > 0 do
    # We send timer messages from the caller process (usually a test process)
    # To garantee that they are delivered to other prcesses before any subsequent calls
    # from the test process to them.
    msgs = :gen_statem.call(@server, {:warp_by, timer_interval, unit})

    Enum.each(msgs, fn msg ->
      send(msg.pid, make_message(msg))
    end)
  end

  @doc """
  Return history of all messages (`%Klotho.Mock.TimerMsg{}`) sent by triggered timers.
  Most recent messages are first.
  """

  @spec timer_event_history() :: [TimerMsg.t()]
  def timer_event_history() do
    :gen_statem.call(@server, :history)
  end

  @doc """
  Freeze time. In `frozen` mode, all calls to `monotonic_time` and `system_time`
  will return the same value. Timers will be not triggered unless warp is called.
  The function is idempotent.
  """

  @spec freeze() :: :ok
  def freeze() do
    :gen_statem.call(@server, :freeze)
  end

  @doc """
  Unreeze time. In `running` mode, all calls to `monotonic_time` and `system_time` will
  start produce values increasing with "normal" monotonic time pace.
  Timers will be triggered according to their schedule.
  """

  @spec unfreeze() :: :ok
  def unfreeze() do
    :gen_statem.call(@server, :unfreeze)
  end

  @doc """
  Reset the state of the time server. This
  * resets the time to the actual current time;
  * cleans timer history;
  * resets the mode to `running`;
  * cancels all timers.
  """

  @spec reset() :: :ok
  def reset() do
    :ok = Supervisor.terminate_child(Klotho.Supervisor, __MODULE__)
    {:ok, _} = Supervisor.restart_child(Klotho.Supervisor, __MODULE__)
    :ok
  end

  # Mocked Time-related Functions

  @doc false
  def monotonic_time(unit) do
    :erlang.convert_time_unit(monotonic_time(), :native, unit)
  end

  @doc false
  def monotonic_time() do
    :gen_statem.call(@server, :monotonic_time)
  end

  @default_send_after_opts %{abs: false}

  @doc false
  def send_after(time, pid, message) when is_non_negative_integer(time) and is_reciever(pid) do
    :gen_statem.call(
      @server,
      {:create_timer, {:send_after, time, pid, message, @default_send_after_opts}}
    )
  end

  @doc false
  def send_after(time, pid, message, opts) when is_reciever(pid) do
    opts = timer_opts(@default_send_after_opts, opts)

    if not opts[:abs] and time <= 0 do
      raise ArgumentError
    end

    :gen_statem.call(@server, {:create_timer, {:send_after, time, pid, message, opts}})
  end

  @default_start_timer_opts %{abs: false}

  @doc false
  def start_timer(time, pid, message) when is_non_negative_integer(time) and is_reciever(pid) do
    :gen_statem.call(
      @server,
      {:create_timer, {:start_timer, time, pid, message, @default_start_timer_opts}}
    )
  end

  @doc false
  def start_timer(time, pid, message, opts)
      when is_reciever(pid) do
    opts = timer_opts(@default_start_timer_opts, opts)

    if not opts[:abs] and time <= 0 do
      raise ArgumentError
    end

    :gen_statem.call(@server, {:create_timer, {:start_timer, time, pid, message, opts}})
  end

  @doc false
  def read_timer(ref) when is_reference(ref) do
    :gen_statem.call(@server, {:read_timer, ref})
  end

  @default_cancel_timer_opts %{info: true, async: false}

  @doc false
  def cancel_timer(ref) when is_reference(ref) do
    :gen_statem.call(@server, {:cancel_timer, {self(), ref}, @default_cancel_timer_opts})
  end

  @doc false
  def cancel_timer(ref, opts) when is_reference(ref) do
    opts = timer_opts(@default_cancel_timer_opts, opts)
    :gen_statem.call(@server, {:cancel_timer, {self(), ref}, opts})
  end

  @doc false
  def system_time() do
    :gen_statem.call(@server, :system_time)
  end

  @doc false
  def system_time(unit) do
    :erlang.convert_time_unit(system_time(), :native, unit)
  end

  @doc false
  def time_offset() do
    :gen_statem.call(@server, :time_offset)
  end

  @doc false
  def time_offset(unit) do
    :erlang.convert_time_unit(time_offset(), :native, unit)
  end

  # :gen_statem callbacks

  @doc false
  def callback_mode(), do: :state_functions

  @doc false
  def init([:frozen]) do
    time = :erlang.monotonic_time()

    {:ok, :frozen,
     %Data{
       time: time,
       start_time: time,
       start_system_time: :erlang.system_time()
     }}
  end

  @doc false
  def init([:running]) do
    time = :erlang.monotonic_time()

    {:ok, :running,
     %Data{
       time: time,
       unfreeze_time: time,
       start_time: time,
       start_system_time: :erlang.system_time()
     }}
  end

  # States: Running, Frozen, Rescheduling

  ## Frozen state

  @doc false
  def frozen({:call, from}, {:cancel_timer, {_pid, ref} = args, opts}, data) do
    {maybe_msg, new_messages} = take_msg(ref, data.timer_messages)

    new_data = %Data{
      data
      | timer_messages: new_messages
    }

    {:keep_state, new_data,
     [{:reply, from, cancel_response(maybe_msg, :frozen, data, args, opts)}]}
  end

  def frozen({:call, from}, {:read_timer, ref}, data) do
    maybe_msg = find_msg(ref, data.timer_messages)

    {:keep_state_and_data, [{:reply, from, time_left(maybe_msg, :frozen, data)}]}
  end

  def frozen({:call, from}, :monotonic_time, data) do
    {:keep_state_and_data, [{:reply, from, mocked_monotonic_time(:frozen, data)}]}
  end

  def frozen({:call, from}, :system_time, data) do
    system_time = mocked_monotonic_time(:frozen, data) - data.start_time + data.start_system_time
    {:keep_state_and_data, [{:reply, from, system_time}]}
  end

  def frozen({:call, from}, :time_offset, data) do
    time_offset = data.start_system_time - data.start_time
    {:keep_state_and_data, [{:reply, from, time_offset}]}
  end

  def frozen({:call, from}, :freeze, _data) do
    {:keep_state_and_data, [{:reply, from, :ok}]}
  end

  def frozen({:call, from}, :unfreeze, data) do
    new_data = %Data{
      data
      | unfreeze_time: :erlang.monotonic_time()
    }

    {:next_state, :rescheduling, new_data,
     [{:reply, from, :ok}, {:next_event, :internal, :reschedule}]}
  end

  def frozen({:call, from}, {:create_timer, create_args}, data) do
    msg = make_timer_msg(:frozen, data, create_args)

    new_data = %Data{
      data
      | timer_messages: insert_msg(msg, data.timer_messages)
    }

    {:keep_state, new_data, [{:reply, from, msg.ref}]}
  end

  def frozen({:call, from}, {:warp_by, timer_interval, unit}, data) do
    {msgs, new_data} = warp_by(:frozen, data, timer_interval, unit)
    {:keep_state, new_data, [{:reply, from, msgs}]}
  end

  def frozen({:call, from}, :history, data) do
    {:keep_state_and_data, [{:reply, from, data.timer_message_history}]}
  end

  ## Running state

  @doc false
  def running({:call, from}, {:cancel_timer, {_pid, ref} = args, opts}, data) do
    {maybe_msg, new_messages} = take_msg(ref, data.timer_messages)

    new_data = %Data{
      data
      | timer_messages: new_messages
    }

    {:next_state, :rescheduling, new_data,
     [
       {:reply, from, cancel_response(maybe_msg, :running, data, args, opts)},
       {:next_event, :internal, :reschedule}
     ]}
  end

  def running({:call, from}, {:read_timer, ref}, data) do
    maybe_msg = find_msg(ref, data.timer_messages)

    {:keep_state_and_data, [{:reply, from, time_left(maybe_msg, :running, data)}]}
  end

  def running({:call, from}, :monotonic_time, data) do
    {:keep_state_and_data, [{:reply, from, mocked_monotonic_time(:running, data)}]}
  end

  def running({:call, from}, :system_time, data) do
    system_time = mocked_monotonic_time(:running, data) - data.start_time + data.start_system_time
    {:keep_state_and_data, [{:reply, from, system_time}]}
  end

  def running({:call, from}, :time_offset, data) do
    time_offset = data.start_system_time - data.start_time
    {:keep_state_and_data, [{:reply, from, time_offset}]}
  end

  def running({:call, from}, :freeze, data) do
    new_data = %Data{
      data
      | time: mocked_monotonic_time(:running, data),
        unfreeze_time: nil
    }

    {:next_state, :frozen, new_data, [{:reply, from, :ok}]}
  end

  def running({:call, from}, :unfreeze, _data) do
    {:keep_state_and_data, [{:reply, from, :ok}]}
  end

  def running({:call, from}, {:create_timer, create_args}, data) do
    msg = make_timer_msg(:running, data, create_args)

    new_data = %Data{
      data
      | timer_messages: insert_msg(msg, data.timer_messages)
    }

    {:next_state, :rescheduling, new_data,
     [{:reply, from, msg.ref}, {:next_event, :internal, :reschedule}]}
  end

  def running(:state_timeout, {:send_msg, ref}, data) do
    new_data = send_msg(data, ref)
    {:next_state, :rescheduling, new_data, [{:next_event, :internal, :reschedule}]}
  end

  def running({:call, from}, {:warp_by, timer_interval, unit}, data) do
    {msgs, new_data} = warp_by(:running, data, timer_interval, unit)

    {:next_state, :rescheduling, new_data,
     [{:reply, from, msgs}, {:next_event, :internal, :reschedule}]}
  end

  def running({:call, from}, :history, data) do
    {:keep_state_and_data, [{:reply, from, data.timer_message_history}]}
  end

  ## Rescheduling state

  @doc false
  def rescheduling(:internal, :reschedule, data) do
    new_timer_events = next_event_timer(data)
    {:next_state, :running, data, new_timer_events}
  end

  # Private Functions

  defp warp_by(state, data, timer_interval, unit) do
    timer_interval = :erlang.convert_time_unit(timer_interval, unit, :native)
    real_monotonic_time = :erlang.monotonic_time()
    new_time = mocked_monotonic_time(state, data, real_monotonic_time) + timer_interval

    {msgs, left} = Enum.split_with(data.timer_messages, fn msg -> msg.time <= new_time end)

    {msgs,
     %Data{
       data
       | time: new_time,
         unfreeze_time: real_monotonic_time,
         timer_messages: left,
         timer_message_history: Enum.reverse(msgs) ++ data.timer_message_history
     }}
  end

  defp make_message(%TimerMsg{type: :send_after, message: message}) do
    message
  end

  defp make_message(%TimerMsg{type: :start_timer, message: message, ref: ref}) do
    {:timeout, ref, message}
  end

  defp make_timer_msg(state, data, {type, interval, pid, message, opts}) do
    ref = :erlang.make_ref()

    interval = :erlang.convert_time_unit(interval, :millisecond, :native)

    interval =
      if opts[:abs] do
        interval - mocked_monotonic_time(state, data)
      else
        interval
      end

    time = mocked_monotonic_time(state, data) + interval

    %TimerMsg{
      pid: pid,
      time: time,
      message: message,
      ref: ref,
      type: type
    }
  end

  defp mocked_monotonic_time(state, data) do
    mocked_monotonic_time(state, data, :erlang.monotonic_time())
  end

  defp mocked_monotonic_time(:frozen, data, _real_monotonic_time) do
    data.time
  end

  defp mocked_monotonic_time(:running, data, real_monotonic_time) do
    real_monotonic_time - data.unfreeze_time + data.time
  end

  defp next_event_timer(%Data{timer_messages: []}) do
    []
  end

  defp next_event_timer(%Data{timer_messages: [msg | _]} = data) do
    interval =
      (msg.time - mocked_monotonic_time(:running, data))
      |> to_non_negative()
      |> :erlang.convert_time_unit(:native, :millisecond)

    [{:state_timeout, interval, {:send_msg, msg.ref}}]
  end

  defp insert_msg(new_msg, []) do
    [new_msg]
  end

  defp insert_msg(new_msg, [msg | rest]) do
    if new_msg.time < msg.time do
      [new_msg | [msg | rest]]
    else
      [msg | insert_msg(new_msg, rest)]
    end
  end

  defp take_msg(ref, msgs) do
    case Enum.split_with(msgs, fn msg -> msg.ref == ref end) do
      {[], msgs} -> {nil, msgs}
      {[msg], msgs} -> {msg, msgs}
    end
  end

  defp send_msg(data, ref) do
    {msg, new_messages} = take_msg(ref, data.timer_messages)

    timer_message_history =
      if msg do
        send(msg.pid, make_message(msg))
        [msg | data.timer_message_history]
      else
        data.timer_message_history
      end

    %Data{data | timer_messages: new_messages, timer_message_history: timer_message_history}
  end

  defp find_msg(ref, msgs) do
    Enum.find(msgs, fn msg -> msg.ref == ref end)
  end

  def time_left(nil, _state, _data) do
    false
  end

  def time_left(msg, state, data) do
    (msg.time - mocked_monotonic_time(state, data))
    |> to_non_negative()
    |> :erlang.convert_time_unit(:native, :millisecond)
  end

  defp cancel_response(_msg, _state, _data, _args, %{info: false}) do
    :ok
  end

  defp cancel_response(msg, state, data, {pid, ref}, %{async: true, info: true}) do
    timer_cancel_message = {:cancel_timer, ref, time_left(msg, state, data)}
    send(pid, timer_cancel_message)
    :ok
  end

  defp cancel_response(msg, state, data, _args, %{async: false, info: true}) do
    time_left(msg, state, data)
  end

  defp to_non_negative(number) do
    if number < 0 do
      0
    else
      number
    end
  end

  defp timer_opts(acc, []) do
    acc
  end

  defp timer_opts(acc, [{key, value} | rest]) when is_map_key(acc, key) and is_boolean(value) do
    timer_opts(Map.put(acc, key, value), rest)
  end

  defp timer_opts(_acc, _opts) do
    raise ArgumentError, "Invalid options"
  end
end
