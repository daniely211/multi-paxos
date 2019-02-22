# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Commander do
  def start(config, leader_pid, acceptors, replicas, { ballot, slot_num, cmd } = message) do
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
    end
    listen(state, acceptors, config)
  end

  def listen(state, waitfor, config) do
    monitor = Map.get(config, :monitor)
    server_num = Map.get(config, :server_num)
    slot_num = Map.get(state, :slot_num)
    receive do
      { :p2b, acceptor_pid, b_suggest } ->
        # IO.puts "GOT p2b"
        pid = self()
        curr_ball_pair = Map.get(state, :ballot)
        if b_suggest == curr_ball_pair do
          waitfor = List.delete(waitfor, acceptor_pid)
          if length(waitfor) < (length(Map.get(state, :acceptors)) / 2) do
            # a majority has been reached, so send the decision aroun to all the replica

            replicas = Map.get(state, :replicas)
            cmd = Map.get(state, :command)
            for replica <- replicas do
              send replica, { :decision, slot_num, cmd }
              # IO.puts "Sending command #{inspect cmd}, at slot number #{inspect slot_num}"
            end
            # send monitor, { :commander_finished, server_num }
          else
            listen(state, waitfor, config)
          end
        else
          # ballot number must be larger than current b than so the commander will tell leader he will not wait for more
          send Map.get(state, :leader), { :preempted, b_suggest }
          # send monitor, { :commander_finished, server_num }

        end
    end
  end
end
