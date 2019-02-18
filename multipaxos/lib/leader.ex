# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Leader do
  def start(config) do
    state = %{
      ballot_number: { 0, self() },
      active: false,
      proposals: MapSet.new()
    }

    receive do
      { :leader_bind_acc_repl, acceptors, replicas } ->
        state = Map.put(state, :acceptors, acceptors)
        state = Map.put(state, :replicas, replicas)
        spawn(Scout, :start, [self(), acceptors, Map.get(state, :ballot_number)]))
        listen(state)
    end
  end

  def listen(state) do
    receive do
      { :propose, slot_no, com } ->
        proposal_exists = false

        Enum.each(Map.get(state, :proposals), fn { p_slot_no, p_com } ->
          if p_slot_no == slot_no do
            proposal_exists = true
          end
        end)

        if not proposal_exists do
          proposals = Map.get(state, :proposals)
          proposals = MapSet.put(proposals, { slot_no, com })
          state = Map.put(state, :proposals, proposals)

          if Map.get(state, :active) do
            acceptors = Map.get(state, :acceptors)
            replicas = Map.get(state, :replicas)
            ballot_number = Map.get(state, :ballot_number)
            message = { ballot_number, slot_no, com }

            spawn(Commander, :start, [self(), acceptors, replicas, message]))
          end
        end
        listen(state)

      { :adopted, ballot_num, pvals } ->
        proposals = Leader.triangle_function(proposals, Leader.pmax(pvals))
        Map.set(state, :proposals, proposals)

        Enum.each(proposals, fn { p_slot_no, p_com } ->
          acceptors = Map.get(state, :acceptors)
          replicas = Map.get(state, :replicas)
          ballot_number = Map.get(state, :ballot_number)
          message = { ballot_number, slot_no, com }

          spawn(Commander, :start, [self(), acceptors, replicas, message])
        end)

        listen(state)

      { :preempted, { r_ballot_number, r_pid } } ->
        if r_ballot_number > Map.get(state, :ballot_number) do
          Map.put(state, :active, false)
          Map.put(state, :ballot_number, { r_ballot_number + 1, self() })
          acceptors = Map.get(state, :acceptors)
          ballot_number = Map.get(state, :ballot_number)

          spawn(Scout, :start, [self(), acceptors, ballot_number])
        end
        listen(state)

    end
  end

  def pmax(pvals) do
    # get unique slot numbers in pval list
    slot_nums = Enum.uniq(Enum.map(pvals, fn {_b, s, _c} -> s end))
    max_pvals = MapSet.new()

    for slot_number <- slot_nums, do
      # get all the relevant pval for this slot number first
      pvals_slot = Enum.filter(pvals, fn { _b, s ,_c } -> s == slot_number end)
      # find the max ballot count first
      max_b = Enum.max(Enum.map(pvals_slot, fn { { b, _pid} , _s, _c } -> b end))
      # find the command with the highest ballot count
      [{ _, _, max_cmd } | _] = Enum.filter(pvals_slot, fn { { b, _pid }, s , c } -> b == max_b  end)
      # add the new pair {s, c} into the list
      max_pvals = MapSet.put(max_pvals, { slot_number, max_cmd })
    end

    max_pvals
  end

  # test_pval = [{1, 0, 'cmd1'}, {2, 0, 'cmd3'}, {1, 0, 'cmd3'}, {5, 1, 'cmd1'}, {4, 1, 'cmd0'}]

  defp triangle_function(proposals, pmax) do
    filtered_proposals = MapSet.new(Enum.filter(proposals, fn { p_slot_no, _x } ->
      not Enum.any?(pmax, fn { pm_slot_no, _y } -> pm_slot_no == p_slot_no end)
    end))

    MapSet.union(filtered_proposals, pmax)
  end
end
