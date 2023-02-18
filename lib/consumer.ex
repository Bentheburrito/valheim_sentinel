defmodule Sentinel.Consumer do
  use Nostrum.Consumer

  alias Nostrum.Api

  require Logger

  @react_emojis [
    "thonk:381325006761754625",
    "🤔",
    "😂",
    "😭",
    "🇼",
    "🇱"
  ]

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, message, _ws_state}) do
    if message.content == "!info",
      do:
        Api.create_message(message.channel_id, """
        I am a bot made by @Snowful#1234 for the Schrute Farms Valheim + Discord server.
        My GitHub repository: https://github.com/Bentheburrito/valheim_sentinel/
        """)

    if String.starts_with?(message.content, "!say ") and
         message.author.id in Application.get_env(:valheim_sentinel, :oligarchs, []) do
      [_say, channel_id | message_list] = String.split(message.content)
      Api.create_message!(String.to_integer(channel_id), Enum.join(message_list, " "))
    end

    if Enum.random(1..Application.get_env(:valheim_sentinel, :react_chance, 80)) == 1 do
      emoji = Enum.random(@react_emojis)
      Api.create_reaction(message.channel_id, message.id, emoji)
    end
  end

  def handle_event({:INTERACTION_CREATE, _interaction, _ws_state}) do
  end

  def handle_event({:READY, data, _ws_state}) do
    Logger.info("Logged in under user #{data.user.username}##{data.user.discriminator}")
    Api.update_status(:online, "over the Realm", 3)
  end

  # Catch all
  def handle_event(_event) do
    :noop
  end
end
