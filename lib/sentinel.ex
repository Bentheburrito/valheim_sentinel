defmodule Sentinel do
  @moduledoc """
  A Discord bot that reads a dedicated server's logs and parses events from them.
  """

  require Logger

  # why in God's name is it so hard to get the system's utc offset.
  def get_local_utc_offset() do
    {offset, result} = System.cmd("date", ["+%z"])

    if result == 0 do
      {:ok, String.trim(offset)}
    else
      Logger.error("Got result #{result} when getting the date from the system.")
      :error
    end
  end
end
