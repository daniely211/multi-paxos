# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Acceptor do
  def start(config) do
    listen(config, -1, MapSet.new())
  end

  def listen(config, curr_ballot, accepted) do
    pid = self()

    receive do
      { :p1a, scout_pid, ballot_suggest } ->
        if ballot_suggest > curr_ballot do
          send scout_pid, { :p1b, self(), ballot_suggest, accepted }
          listen(config, ballot_suggest, accepted)
        else
          send scout_pid, { :p1b, self(), curr_ballot, accepted }
          listen(config, curr_ballot, accepted)
        end

      { :p2a, commander_pid, { {ballot_suggest, _pid}, _s, _c } = package} ->
        pid = self()
        if ballot_suggest == curr_ballot do
          listen(config, curr_ballot, MapSet.put(accepted, package))
        else
          send commander_pid, { :p2b, self(), curr_ballot }
          listen(config, curr_ballot, accepted)
        end
    end
  end
end
