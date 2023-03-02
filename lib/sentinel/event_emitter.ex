defmodule Sentinel.EventEmitter do
  @moduledoc """
  GenServer that emits events from a server log file with the help of Sentinel.LogParser
  """

  # `associations` maps steam_id => character_name
  @enforce_keys [:stream]
  defstruct stream: nil, last_message_type: nil, associations: %{joining: []}

  use GenServer

  require Logger

  alias Nostrum.Api
  alias Sentinel.LogParser
  alias Sentinel.LogParser.Entry

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
    {last_message_type, associations} =
      for line <- state.stream, reduce: {state.last_message_type, state.associations} do
        {event_type, associations} ->
          case LogParser.parse_log_line_event(line) do
            {:ok, %Entry{} = entry} ->
              {new_associations, %Entry{} = entry} = match_associations(associations, entry)

              Logger.info(entry.message)

              new_event_type =
                "LOG_CHANNEL_ID"
                |> System.get_env(@default_channel_id)
                |> String.to_integer()
                |> send_new(entry.message, entry.type, event_type)

              {new_event_type, new_associations}

            _ ->
              {event_type, associations}
          end
      end

    Process.send_after(self(), :check_log, @check_log_interval_ms)

    {:noreply,
     %__MODULE__{state | last_message_type: last_message_type, associations: associations}}
  end

  defp match_associations(associations, %Entry{type: :steam_user_joined} = entry) do
    with [_, steam_id] <- entry.captures,
         :error <- Map.fetch(associations, steam_id) do
      {Map.update(associations, :joining, [steam_id], &[steam_id | &1]), entry}
    else
      {:ok, name} ->
        steam_id = Enum.at(entry.captures, 1)
        update_entry_message(entry, steam_id, name, associations)

      _ ->
        {associations, entry}
    end
  end

  defp match_associations(associations, %Entry{type: :player_joined} = entry) do
    with [_, name] <- entry.captures,
         false <- Enum.any?(associations, fn {_steam_id, char_name} -> char_name == name end),
         [joining_steam_id] <- Map.get(associations, :joining) do
      new_associations =
        associations
        |> Map.put(joining_steam_id, name)
        |> Map.put(:joining, [])

      {new_associations, entry}
    else
      true -> {associations, entry}
      _ -> {Map.put(associations, :joining, []), entry}
    end
  end

  defp match_associations(associations, %Entry{type: :steam_user_disconnect} = entry) do
    with [_, steam_id] <- entry.captures,
         {:ok, name} <- Map.fetch(associations, steam_id) do
      update_entry_message(entry, steam_id, name, associations)
    else
      _ -> {associations, entry}
    end
  end

  defp match_associations(associations, entry), do: {associations, entry}

  defp update_entry_message(entry, steam_id, name, associations) do
    captures = [nil, "#{name} (#{steam_id})"]

    new_entry =
      case LogParser.build_event_message(entry.type, captures, entry.timestamp) do
        {:ok, message} -> %Entry{entry | message: message}
        :none -> entry
      end

    {associations, new_entry}
  end

  # Only send this message if it isn't a consecutive World Saved message.
  defp send_new(channel_id, message, event_type, last_message_type) do
    if event_type == :world_saved and event_type == last_message_type do
      last_message_type
    else
      case Api.create_message(channel_id, message) do
        {:error, {:stream_error, :closed}} ->
          Logger.warn(
            "Got {:error, {:stream_error, :closed}}, trying to resend message once: #{inspect(message)}"
          )

          Api.create_message(channel_id, message)

        _ ->
          nil
      end

      event_type
    end
  end
end
