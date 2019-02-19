# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Acceptor do
  def start(config) do
    pid = self()
    IO.puts "ACCEPTOR ALIVE I AM #{inspect pid}"
    listen(config, -1, MapSet.new())
  end

  def listen(config, curr_ballot, accepted) do
    pid = self()

    receive do
      { :p1a, scout_pid, ballot_suggest } ->
        IO.puts "GOT A p1a i am #{inspect pid} ballot suggest is #{inspect ballot_suggest}"
        if ballot_suggest > curr_ballot do
          IO.puts "Sending P1b i am#{inspect pid}"
          send scout_pid, { :p1b, self(), ballot_suggest, accepted }
          listen(config, ballot_suggest, accepted)
        else
          IO.puts "But the ballot suggested is less than the current ballot "
          send scout_pid, { :p1b, self(), curr_ballot, accepted }
          listen(config, curr_ballot, accepted)
        end

      { :p2a, commander_pid, { ballot_suggest, _s, _c } = package} ->
        pid = self()
        IO.puts "GOT P2A in ACCEPTOR! from #{inspect commander_pid} i am #{inspect pid} "
        if ballot_suggest == curr_ballot do
          listen(config, curr_ballot, MapSet.put(accepted, package))
        else
          IO.puts "SENDING p2b with #{inspect curr_ballot} ballot to #{inspect commander_pid} i am #{inspect pid} "
          send commander_pid, { :p2b, self(), curr_ballot }
          listen(config, curr_ballot, accepted)
        end
    end
  end
end
