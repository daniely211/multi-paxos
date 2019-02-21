# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Acceptor do
  def start(config) do
    listen(config, -1, MapSet.new())
  end

  def listen(config, curr_ballot, accepted) do
    # pid = self()

    receive do
      { :p1a, scout_pid, { ballot_suggest, _pid } } ->
        if ballot_suggest > curr_ballot do
          send scout_pid, { :p1b, self(), ballot_suggest, accepted }
          listen(config, ballot_suggest, accepted)
        else
          send scout_pid, { :p1b, self(), curr_ballot, accepted }
          listen(config, curr_ballot, accepted)
        end

      { :p2a, commander_pid, { {ballot_suggest, _pid}, _s, _c } = package} ->
        # IO.puts "GOT p2a for #{inspect ballot_suggest}, curr ballot is #{inspect curr_ballot} "
        if ballot_suggest == curr_ballot do
          # IO.puts "SENDING p2b ballot is the same"
          send commander_pid, { :p2b, self(), curr_ballot }
          listen(config, curr_ballot, MapSet.put(accepted, package))
        end
        # IO.puts "SENDING p2b "
        send commander_pid, { :p2b, self(), curr_ballot }
        listen(config, curr_ballot, accepted)
    end
  end
end
