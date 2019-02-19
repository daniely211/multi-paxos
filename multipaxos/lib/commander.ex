# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Commander do
  def start(leader_pid, acceptors, replicas, { ballot, slot_num, cmd } = message) do
    state = %{
      acceptors: acceptors,
      replicas: replicas,
      leader: leader_pid,
      ballot: ballot,
      slot_num: slot_num,
      command: cmd
    }

    for acceptor <- acceptors do
      send acceptor, { :p2a, self(), message }
      listen(state, acceptors)
    end
  end

  def listen(state, waitfor) do
    receive do
      { :p2b, acceptor_pid, b_suggest } ->
        if b_suggest == Map.get(state, :ballot) do
          waitfor = List.delete(waitfor, acceptor_pid)
          if length(waitfor) < (length(Map.get(state, :acceptors)) / 2) do
            # a majority has been reached, so send the decision aroun to all the replica
            replicas = Map.get(state, :replicas)
            for replica <- replicas do
              send replica, { :decision, Map.get(state, :slot_number), Map.get(state, :command) }
              # do not recurse here
            end
          else
            listen(state, waitfor)
          end
        else
          send Map.get(state, :leader), { :preempted, b_suggest }
          # do not recurse here
        end
    end
  end
end
