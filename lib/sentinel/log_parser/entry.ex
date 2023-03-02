defmodule Sentinel.LogParser.Entry do
  @enforce_keys [:type, :timestamp, :captures, :raw_message]
  defstruct type: nil, timestamp: nil, captures: nil, raw_message: nil, message: ""

  @type t() :: %__MODULE__{
          type: atom(),
          timestamp: DateTime.t(),
          captures: [String.t()],
          raw_message: String.t(),
          message: String.t()
        }

  def new(type, timestamp, captures, raw_message, message \\ "")
      when is_atom(type) and is_list(captures) do
    %Sentinel.LogParser.Entry{
      type: type,
      timestamp: timestamp,
      captures: captures,
      raw_message: raw_message,
      message: message
    }
  end
end
