# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Replica do
  def start(config, database, monitor) do
    initial_state = %{
      clients: MapSet.new(),
      slot_in: 1,
      slot_out: 1,
      requests: MapSet.new(),
      proposals: MapSet.new(),
      decision: MapSet.new()
    }

    receive do
      { :replica_bind_leader, leaders } -> listen(initial_state, leaders)
    end
  end

  def propose(state) do
    window = Map.get(state, :window)

    requests = Map.get(state, :requests)
    remove_requests = MapSet.new()

    Enum.each(requests, fn c ->
      slot_in = Map.get(state, :slot_in)
      slot_out = Map.get(state, :slot_out)

      if slot_in < slot_out + window do
        leaders = MapSet.new()

        Enum.each(Map.get(state, :decisions), fn { d_slot_no, { _x, _y, op } } ->
          if isreconfig(op) do
            leaders = op.leaders
          end
        end)

        Enum.each(Map.get(state, :decisions), fn { d_slot_no, { _x, _y, op } } ->
          if d_slot_no == slot_in do
            remove_requests = MapSet.put(remove_requests, c)

            proposals = Map.get(state, :proposals)
            proposals = MapSet.put(proposals, { slot_in, c })
            state = Map.put(state, :proposals, proposals)

            for leader <- leaders, do: send leader { :propose, slot_in, c }
          end
        end)

        Map.put(state, :slot_in, slot_in + 1)
      end
    end)

    new_requests = MapSet.difference(requests, remove_requests)
    state = Map.put(state, :requests, new_requests)
  end

  def isreconfig(op) do
    # TODO: what is this for
  end

  def perform(state, { client, cid, op } = com) do
    slot_out = Map.get(state, :slot_out)

    Enum.each(Map.get(state, :decisions), fn { d_slot_no, { client, cid, op } }) ->
      if d_slot_no < slot_out or isreconfig(op) do
        Map.put(state, :slot_out, slot_out + 1)
      else
        # { next, result } = op(state)
        # atomic: state = next
        # slot_out += 1

        send client { :response, cid, result }
      end
    end)
  end

  def listen(state, leaders) do
    receive do
      { :request, client } ->
        requests = Map.get(state, :requests)
        requests = MapSet.put(requests, { d_slot_no, d_cmd })
        state = Map.put(state, :requests, requests)

        # TODO: check this is right
        propose(state)

      { :decision, d_slot_no, d_cmd } ->
        decisions = Map.get(state, :decisions)
        decisions = MapSet.put(decisions, { d_slot_no, d_cmd })
        state = Map.put(state, :decisions, decisions)

        for { slot_no, com } = d <- decisions, do: process_decision(state, d)
    end

    propose(state)
  end

  defp process_decisions(state, { d_slot_no, d_com }) do
    slot_out = Map.get(state, :slot_out)

    if d_slot_no == slot_out do
      proposals = Map.get(state, :proposals)
      remove_proposals = MapSet.new()

      Enum.each(proposals, fn { p_slot_no, p_com } ->

        if p_slot_no == slot_out do
          remove_proposals = MapSet.put(remove_proposals, { p_slot_no, p_com })

          if d_com != p_com do
            requests = Map.get(state, :requests)
            requests = MapSet.put(requests, { p_com })
            state = Map.put(state, :requests, requests)
          end
        end
      end)

      new_proposals = MapSet.difference(proposals, remove_proposals)
      state = Map.put(state, :proposals, new_proposals)

      perform(state, d_com)
    end
  end
end
