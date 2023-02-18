defmodule Sentinel.LogParser do
  @moduledoc """
  Contains helper fns to parse Valheim server logs.
  """

  require Logger

  def log_event_regexes do
    [
      player_died: ~r/Got character ZDOID from (?P<viking>\w+[ \w+]*) : 0:0/,
      player_joined: ~r/Got character ZDOID from (?P<viking>\w+[ \w+]*) : [-0-9]*:1$/,
      game_server_connected: ~r/Game server connected/,
      game_server_shutdown: ~r/OnApplicationQuit/,
      world_saved: ~r/World saved \( (\d+\.\d+ms) \)/,
      random_event: ~r/.*? Random event set:(\w+)/,
      valheim_version: ~r/Valheim version:(\d+\.\d+\.\d+)/,
      steam_user_joined: ~r/Got connection SteamID (\d+)/,
      steam_user_disconnect: ~r/Closing socket (\d+)/,
      # when interacting with eikthyr location stone at main stones
      # 01/20/2023 10:34:15: Found location of type Eikthyrnir
      found_location: ~r/Found location of type (\w+)/
    ]
  end

  @doc """
  Creates a new IO stream with the given log path.
  """
  def new_log_stream(log_path) do
    case File.open(log_path) do
      {:ok, file} ->
        {:ok, IO.stream(file, :line)}

      {:error, reason} ->
        Logger.error("Could not open log file #{log_path} with reason #{reason}")
        {:error, reason}
    end
  end

  @spec parse_log_line_event(String.t()) :: {:ok, event :: any()} | :invalid
  def parse_log_line_event(line) do
    with {:ok, timestamp} <- parse_log_line_timestamp(line),
         {event_name, captures} <- match_event_regex(line),
         {:ok, message} <- build_event_message(event_name, captures, timestamp) do
      {:ok, message}
    else
      _ -> :invalid
    end
  end

  defp build_event_message(event_name, captures, timestamp) do
    case event_text(event_name, captures) do
      :none -> :none
      text -> {:ok, "#{server_signature(timestamp)} #{text}"}
    end
  end

  defp event_text(:player_died, [_, viking]), do: "🪦 #{viking} has been slain"
  defp event_text(:player_joined, [_, viking]), do: "#{viking} joined the server"
  defp event_text(:game_server_connected, [_]), do: "Server online"
  defp event_text(:game_server_shutdown, [_]), do: "Server offline"
  defp event_text(:world_saved, [_, time]), do: "☑️ World saved in #{time}"
  defp event_text(:random_event, [_, type]), do: "⚔️ A #{type} event has started!"
  defp event_text(:steam_user_joined, [_, steamid]), do: "User connecting: #{steamid}"
  defp event_text(:steam_user_disconnect, [_, steamid]), do: "User disconnected: #{steamid}"
  defp event_text(_, _), do: :none

  defp server_signature(timestamp) do
    server_name = System.get_env("LOG_MESSAGE_AUTHOR", "Server")
    "<#{server_name} @ <t:#{DateTime.to_unix(timestamp)}>>"
  end

  def match_event_regex(line) do
    Enum.find_value(log_event_regexes(), fn {event_name, regex} ->
      case Regex.run(regex, line) do
        nil -> false
        captures -> {event_name, captures}
      end
    end)
  end

  @spec parse_log_line_timestamp(String.t()) :: {:ok, dt :: DateTime.t()} | :invalid
  def parse_log_line_timestamp(line) do
    with [date, time] <- line |> String.slice(0..18) |> String.split(" "),
         [month, day, year] <- String.split(date, "/"),
         {:ok, offset} <- Sentinel.get_local_utc_offset(),
         {:ok, dt, offset} <- DateTime.from_iso8601("#{year}-#{month}-#{day}T#{time}#{offset}") do
      {:ok, %DateTime{dt | utc_offset: offset}}
    else
      _ ->
        :invalid
    end
  end
end