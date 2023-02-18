defmodule Sentinel.EventEmitter do
  @moduledoc """
  GenServer that emits events from a server log file with the help of Sentinel.LogParser
  """

  @enforce_keys [:stream]
  defstruct stream: nil, last_message_type: nil

  use GenServer

  require Logger

  alias Nostrum.Api
  alias Sentinel.LogParser

  @default_channel_id "381258231613227020"
  @check_log_interval_ms 1000

  ## API

  def start_link(log_path) do
    GenServer.start_link(__MODULE__, log_path, name: __MODULE__)
  end

  ## IMPL

  @impl true
  def init(nil) do
    {:stop, "Got `nil` for log_path. Please specify the LOG_PATH environment variable"}
  end

  @impl true
  def init(log_path) do
    {:ok, stream} = LogParser.new_log_stream(log_path)

    # Skip old logs
    for _line <- stream, do: nil

    send(self(), :check_log)
    {:ok, %__MODULE__{stream: stream, last_message_type: nil}}
  end

  @impl true
  def handle_info(:check_log, %__MODULE__{} = state) do
    last_message_type =
      for line <- state.stream, reduce: state.last_message_type do
        message_type ->
          case LogParser.parse_log_line_event(line) do
            {:ok, event_type, message} ->
              Logger.info(message)

              "LOG_CHANNEL_ID"
              |> System.get_env(@default_channel_id)
              |> String.to_integer()
              |> send_new(message, event_type, state.last_message_type)

            _ ->
              message_type
          end
      end

    Process.send_after(self(), :check_log, @check_log_interval_ms)
    {:noreply, %__MODULE__{state | last_message_type: last_message_type}}
  end

  # Only send this message if it isn't a consecutive World Saved message.
  defp send_new(channel_id, message, event_type, last_message_type) do
    if event_type == :world_saved and event_type == last_message_type do
      last_message_type
    else
      Api.create_message(channel_id, message)
      event_type
    end
  end
end
