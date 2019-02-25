# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Acceptor do
  def start(config) do
    listen(config, -1, MapSet.new())
  end

  def listen(config, curr_ballot, accepted) do

    receive do
      { :p1a, scout_pid, ballot_pair } ->
        if ballot_pair > curr_ballot do
          send scout_pid, { :p1b, self(), ballot_pair, accepted }
          listen(config, ballot_pair, accepted)
        else
          send scout_pid, { :p1b, self(), curr_ballot, accepted }
          listen(config, curr_ballot, accepted)
        end

      { :p2a, commander_pid, { ballot_pair, _s, _c } = package} ->
        if ballot_pair == curr_ballot do
          send commander_pid, { :p2b, self(), curr_ballot }
          listen(config, curr_ballot, MapSet.put(accepted, package))
        end
        send commander_pid, { :p2b, self(), curr_ballot }
        listen(config, curr_ballot, accepted)
    end
  end
end
