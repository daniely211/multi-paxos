# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Leader do
  def start(config) do
    state = %{
      ballot_number: { 0, self() },
      active: false,
      proposals: MapSet.new(),
      acceptors: MapSet.new(),
      replicas: MapSet.new()
    }
    monitor = Map.get(config, :monitor)
    server_num = Map.get(config, :server_num)

    receive do
      { :leader_bind_acc_repl, acceptors, replicas } ->
        state = %{ state | acceptors: acceptors, replicas: replicas }
        spawn(Scout, :start, [config, self(), acceptors, Map.get(state, :ballot_number)])
        send monitor,{ :scout_spawned, server_num  }
        listen(config, state, 0)
    end
  end

  defp pmax(pvals) do
    # get unique slot numbers in pval list
    slot_nums = Enum.uniq(Enum.map(pvals, fn {_b, s, _c} -> s end))

    max_pvals = MapSet.new(Enum.map(slot_nums, fn slot_number ->
      # get all the relevant pval for this slot number first
      pvals_slot = Enum.filter(pvals, fn { _b, s ,_c } -> s == slot_number end)
      # find the max ballot count first
      max_b = Enum.max(Enum.map(pvals_slot, fn { { b, _pid} , _s, _c } -> b end))
      # find the command with the highest ballot count
      [{ _, _, max_cmd } | _] = Enum.filter(pvals_slot, fn { { b, _pid }, _s , _c } -> b == max_b  end)
      # add the new pair {s, c} into the list
      { slot_number, max_cmd }
    end))

    max_pvals
  end

  def listen(config, state, timeout) do
    monitor = Map.get(config, :monitor)
    server_num = Map.get(config, :server_num)
    receive do
      { :propose, slot_no, com } ->
        # IO.puts "I AM LEAEDER #{inspect pid}, got a proposal #{inspect com} "

        active = Map.get(state, :active)
        proposals = Map.get(state, :proposals)

        # Leader will only accept the proposal if there arent any conflicting proposals in the same time slot
        proposal_exists = Enum.any?(proposals, fn { p_slot_no, _c } ->
          p_slot_no == slot_no
        end)

        if not proposal_exists do
          proposals = MapSet.put(proposals, { slot_no, com })
          state = %{ state | proposals: proposals }
          # no conflicting proposal, will spawn a commander if leader is active.
          # IO.puts "I AM LEAEDER #{inspect pid}, no conflicting proposal"
          if active do
            # IO.puts "I AM LEAEDER #{inspect pid}, no conflicting proposal, will spawn a commander for proposal #{inspect com}"
            acceptors = Map.get(state, :acceptors)
            replicas = Map.get(state, :replicas)
            ballot_number = Map.get(state, :ballot_number)
            message = { ballot_number, slot_no, com }
            spawn(Commander, :start, [config, self(), acceptors, replicas, message])
            send monitor,{ :commander_spawned, server_num  }
          end
          listen(config, state, timeout)
        end

        listen(config, state, timeout)

      { :adopted, ballot_pair, pvals } ->
        # timeout should decrease linearly
        timeout = max(0, timeout - 5)

        # IO.puts "GOT ADDOPTED MESSAGE"
        proposals = Map.get(state, :proposals)
        proposals = triangle_function(proposals, pmax(pvals))
        state = %{ state | proposals: proposals }

        # for the first round of scouts that send adopted, there will be no proposals since clients hasnt started sending
        # Here leader loops through the proposals sent by the replica which got it from client
        # and spawn a comander PER proposal.
        Enum.each(proposals, fn { p_slot_no, p_com } ->
          acceptors = Map.get(state, :acceptors)
          replicas = Map.get(state, :replicas)
          message = { ballot_pair, p_slot_no, p_com }
          spawn(Commander, :start, [config, self(), acceptors, replicas, message])
          send monitor,{ :commander_spawned, server_num  }
        end)
        # IO.puts "LEADER GOING TO ACTIVE #{inspect server_num}"

        state = %{ state | active: true }
        listen(config, state, timeout)

      { :preempted, { r_ballot_number, _r_pid } = ballot_pair_suggest } ->
        timeout = 1 + round(timeout * 1.05)
        Process.sleep(timeout)

        cur_ballot_pair = Map.get(state, :ballot_number)

        if ballot_pair_suggest > cur_ballot_pair do
          # it is no longer possible to use current b_num to choose a command.
          # IO.puts "LEADER GOING TO PASSIVE #{inspect server_num}"
          state = %{ state | active: false, ballot_number: { r_ballot_number + 1, self() } }
          acceptors = Map.get(state, :acceptors)
          new_ballot_pair = Map.get(state, :ballot_number)

          # spawn a new scout with a new ballot number which is the r_ballot_number + 1
          spawn(Scout, :start, [config, self(), acceptors, new_ballot_pair])
          send monitor,{ :scout_spawned, server_num }
          listen(config, state, timeout)
        end

        listen(config, state, timeout)
    end
  end



  defp triangle_function(proposals, pmax) do
    filtered_proposals = MapSet.new(Enum.filter(proposals, fn { p_slot_no, _x } ->
      not Enum.any?(pmax, fn { pm_slot_no, _y } -> pm_slot_no == p_slot_no end)
    end))

    MapSet.union(filtered_proposals, pmax)
  end
end
