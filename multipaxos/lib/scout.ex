# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Scout do
  def start(leader_pid, acceptors, ballot_num) do
    state = %{
      acceptors: acceptors,
      leader: leader_pid,
      ballot_num: ballot_num,
      pvalues: MapSet.new()
    }

    for acceptor <- acceptors do
      send acceptor, { :p1a, self(), ballot_num }
    end
    listen(state, acceptors)

  end

  def listen(state, waitfor) do
    receive do
      { :p1b, acceptor_pid, ballot_suggest, p_val } ->
        if ballot_suggest == Map.get(state, :ballot_num) do

          pvalues = Map.get(state, :pvalues)
          pvalues = MapSet.union(pvalues, p_val)
          state = %{ state | pvalues: pvalues }

          waitfor = List.delete(waitfor, acceptor_pid)
          if length(waitfor) < (length(Map.get(state, :acceptors)) / 2) do
            # a majority has been reached, so send the decision aroun to all the replica
            pvals = Map.get(state, :pvalues)
            send Map.get(state, :leader), { :adopted, ballot_suggest, pvals }
          else

            listen(state, waitfor)
          end
        else
          send Map.get(state, :leader), { :preempted, ballot_suggest }
        end
    end
  end
end
