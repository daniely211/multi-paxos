# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Replica do
  def start(config, database, monitor) do
    initial_state = %{
      clients: MapSet.new(),
      slot_in: 1,
      slot_out: 1,
      requests: MapSet.new(),
      proposals: MapSet.new(),
      decision: MapSet.new(),
      leaders: MapSet.new()
    }

    receive do
      { :replica_bind_leader, leaders } ->
        state = Map.get_and_update(state, :leaders, fn val ->
          { val, leaders }
        end)
        listen(state)
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
            # TODO: may need to figure out how to remove it from requests list
            # within the iteration
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

    requests = MapSet.difference(requests, remove_requests)
    state = Map.put(state, :requests, requests)

    listen(state)
  end

  def isreconfig(op) do
    # TODO: figure out what a reconfig operation looks like
  end

  def perform(state, { client, cid, op } = com) do
    slot_out = Map.get(state, :slot_out)

    Enum.each(Map.get(state, :decisions), fn { d_slot_no, { client, cid, op } }) ->
      if d_slot_no < slot_out or isreconfig(op) do
        Map.put(state, :slot_out, slot_out + 1)
      else
        # TODO
        # { next, result } = op(state)
        # atomic: state = next
        # slot_out += 1

        send client { :response, cid, result }
      end
    end)
  end

  def listen(state) do
    receive do
      { :client_request, client } ->
        requests = Map.get(state, :requests)
        requests = MapSet.put(requests, { d_slot_no, d_cmd })
        state = Map.put(state, :requests, requests)
        propose(state)

      { :decision, d_slot_no, d_cmd } ->
        decisions = Map.get(state, :decisions)
        decisions = MapSet.put(decisions, { d_slot_no, d_cmd })
        state = Map.put(state, :decisions, decisions)

        for { slot_no, com } = d <- decisions, do
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

            proposals = MapSet.difference(proposals, remove_proposals)
            state = Map.put(state, :proposals, proposals)

            perform(state, d_com)
          end
        end

        propose(state)
    end
  end
end
