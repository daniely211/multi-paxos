# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Scout do
  def start(config, leader_pid, acceptors, ballot_num) do
    state = %{
      acceptors: acceptors,
      leader: leader_pid,
      ballot_num: ballot_num,
      pvalues: MapSet.new()
    }
    for acceptor <- acceptors do
      send acceptor, { :p1a, self(), ballot_num }
    end
    listen(state, acceptors, config)

  end

  def listen(state, waitfor, config) do
    monitor = Map.get(config, :monitor)
    server_num = Map.get(config, :server_num)
    receive do
      { :p1b, acceptor_pid, { ballot_suggest, _pid } = ballot_pair, p_val } ->
        curr_ballot_pair = Map.get(state, :ballot_num)
        if ballot_pair == curr_ballot_pair do

          pvalues = Map.get(state, :pvalues)
          pvalues = MapSet.union(pvalues, p_val)
          state = %{ state | pvalues: pvalues }

          waitfor = List.delete(waitfor, acceptor_pid)
          if length(waitfor) < (length(Map.get(state, :acceptors)) / 2) do
            # a majority has been reached, so send the decision aroun to all the replica
            pvals = Map.get(state, :pvalues)
            send Map.get(state, :leader), { :adopted, ballot_pair, pvals }
            send monitor, { :scout_finished, server_num }
          else
            listen(state, waitfor, config)
          end
        else
          send Map.get(state, :leader), { :preempted, ballot_suggest }
          send monitor, { :scout_finished, server_num }
        end
    end
  end
end
