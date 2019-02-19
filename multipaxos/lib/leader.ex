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

    receive do
      { :leader_bind_acc_repl, acceptors, replicas } ->
        state = %{ state | acceptors: acceptors, replicas: replicas }
        spawn(Scout, :start, [self(), acceptors, Map.get(state, :ballot_number)])
        listen(state)
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

  def listen(state) do
    receive do
      { :propose, slot_no, com } ->
        active = Map.get(state, :active)
        proposals = Map.get(state, :proposals)

        proposal_exists = Enum.any?(proposals, fn { p_slot_no, _c } ->
          p_slot_no == slot_no
        end)

        if not proposal_exists do
          proposals = MapSet.put(proposals, { slot_no, com })
          state = %{ state | proposals: proposals }

          if active do
            acceptors = Map.get(state, :acceptors)
            replicas = Map.get(state, :replicas)
            ballot_number = Map.get(state, :ballot_number)
            message = { ballot_number, slot_no, com }
            spawn(Commander, :start, [self(), acceptors, replicas, message])
          end

          listen(state)
        end

        listen(state)

      { :adopted, ballot_num, pvals } ->
        # IO.puts "PVALS IN LEADER #{inspect pvals}"
        proposals = Map.get(state, :proposals)
        proposals = triangle_function(proposals, pmax(pvals))
        state = %{ state | proposals: proposals }

        Enum.each(proposals, fn { p_slot_no, p_com } ->
          acceptors = Map.get(state, :acceptors)
          replicas = Map.get(state, :replicas)
          message = { ballot_num, p_slot_no, p_com }
          spawn(Commander, :start, [self(), acceptors, replicas, message])
        end)

        state = %{ state | active: true }
        listen(state)

      { :preempted, { r_ballot_number, _r_pid } } ->
        { b_num, _ } = Map.get(state, :ballot_number)

        if r_ballot_number > b_num do
          state = %{ state | active: false, ballot_number: { r_ballot_number + 1, self() } }
          acceptors = Map.get(state, :acceptors)
          ballot_number = Map.get(state, :ballot_number)

          spawn(Scout, :start, [self(), acceptors, ballot_number])
          listen(state)
        end

        listen(state)
    end
  end



  defp triangle_function(proposals, pmax) do
    filtered_proposals = MapSet.new(Enum.filter(proposals, fn { p_slot_no, _x } ->
      not Enum.any?(pmax, fn { pm_slot_no, _y } -> pm_slot_no == p_slot_no end)
    end))

    MapSet.union(filtered_proposals, pmax)
  end
end
