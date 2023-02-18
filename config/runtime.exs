import Config

if Config.config_env() == :dev do
  DotenvParser.load_file(".env")
end

config :nostrum,
  token: System.get_env("BOT_TOKEN")

config :valheim_sentinel,
  oligarchs: [254_728_052_070_678_529]
