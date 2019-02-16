# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Scout do
  def start(leader_pid, acceptors, ballot_numb) do
    state = %{
      acceptors: acceptors,
      leader: leader_pid,
      ballot_num: ballot_num,
      pvalues: MapSet.new()
    }

    for acceptor <- acceptors, do
      send acceptor, { :p1a, self(), ballot_number }
      listen(state, acceptors)
    end
  end

  def listen(state, waitfor) do
    receive do
      { :p1b, acceptor_pid, ballot_suggest, p_val } ->
        if ballot_suggest == Map.get(state, :ballot_num) do
          { _, state } = Map.get_and_update(state, :pvalues, fn mapset ->
            { mapset, MapSet.put(mapset, p_val) }
          end)

          waitfor = List.delete(waitfor, acceptor_pid)

          if length(waitfor) < length(Map.get(state, :acceptors)) / 2 do
            # a majority has been reached, so send the decision aroun to all the replica
            send Map.get(state, :leader), { :adopted, ballot_suggest, Map.get(state, :pvalues) }
          else
            listen(state, waitfor)
          end
        else
          send Map.get(state, :leader), { :preempted, ballot_suggest }
        end
    end
  end
end
