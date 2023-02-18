defmodule Sentinel.EventEmitter do
  @moduledoc """
  GenServer that emits events from a server log file with the help of Sentinel.LogParser
  """

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

    start_utc = DateTime.utc_now()

    # Skip old logs
    Enum.reduce_while(stream, nil, fn line, _acc ->
      case LogParser.parse_log_line_timestamp(line) do
        {:ok, dt} ->
          if DateTime.compare(dt, start_utc) == :lt do
            {:cont, nil}
          else
            {:halt, nil}
          end

        _ ->
          {:cont, nil}
      end
    end)

    send(self(), :check_log)
    {:ok, stream}
  end

  @impl true
  def handle_info(:check_log, stream) do
    for line <- stream do
      case LogParser.parse_log_line_event(line) do
        {:ok, message} ->
          Logger.info(message)

          "LOG_CHANNEL_ID"
          |> System.get_env(@default_channel_id)
          |> String.to_integer()
          |> Api.create_message(message)

        _ ->
          nil
      end
    end

    Process.send_after(self(), :check_log, @check_log_interval_ms)
    {:noreply, stream}
  end
end
