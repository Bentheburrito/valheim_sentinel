defmodule Sentinel.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Sentinel.Consumer, name: Sentinel.Consumer},
      {Sentinel.EventEmitter, System.get_env("LOG_PATH")}
    ]

    opts = [strategy: :one_for_one, name: Sentinel.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
