# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Replica do
  def start(config, database, monitor) do
    state = %{
      clients: MapSet.new(),
      slot_in: 1,
      slot_out: 1,
      window: 10,
      requests: MapSet.new(),
      proposals: MapSet.new(),
      decisions: MapSet.new(),
      leaders: MapSet.new(),
      database: database
    }

    receive do
      { :replica_bind_leader, leaders } ->
        { _, s } = Map.get_and_update(state, :leaders, fn val -> { val, leaders } end)
        state = s
        listen(state)
    end
  end

  def propose(state) do
    slot_in = Map.get(state, :slot_in)
    slot_out = Map.get(state, :slot_out)
    window = Map.get(state, :window)
    requests = Map.get(state, :requests)
    proposals = Map.get(state, :proposals)
    decisions = Map.get(state, :decisions)
    leaders = Map.get(state, :leaders)

    if slot_in < slot_out + window and MapSet.size(requests) > 0 do

      # if there are no decisions with the current slot numbe
      if not Enum.any?(decisions, fn { s, _cmd } -> s == slot_in end) do
        req_arb = Enum.random(requests)
        requests = MapSet.delete(requests, req_arb)
        proposals = MapSet.put(proposals, { slot_in, req_arb })

        state = %{ state | proposals: proposals, requests: requests }

        for leader <- leaders, do: send leader, { :propose, slot_in, req_arb }

        state = %{ state | slot_out: slot_out + 1 }
        propose(state)
      else
        state = %{ state | slot_out: slot_out + 1 }
        propose(state)
      end
    else
      listen(state)
    end
  end

  def perform(state, { client, cid, op }) do
    slot_out = Map.get(state, :slot_out)

    if Enum.any?(Map.get(state, :decisions), fn { s, _c } -> s < slot_out end) do
      state = %{ state | slot_out: slot_out + 1 }
      decisions_ready(state)
    else
      # TODO
      database = Map.get(state, :database)
      send database, { :execute, op }
      IO.puts "send #{inspect op} to DB!!"

      # TODO:
      # atomic:
        # state = next
        # slot_out += 1

      # send client, { :response, cid, result }
      decisions_ready(state)
    end
  end

  def listen(state) do
    receive do
      { :client_request, req } ->
        requests = Map.get(state, :requests)
        requests = MapSet.put(requests, req)
        state = %{ state | requests: requests }
        propose(state)

      { :decision, d_slot_no, d_cmd } ->
        IO.puts "DECISION READY!!!"
        decisions = Map.get(state, :decisions)
        decisions = MapSet.put(decisions, { d_slot_no, d_cmd })
        state = %{ state | decisions: decisions }
        decisions_ready(state)

    end
  end

  defp decisions_ready(state) do
    decisions = Map.get(state, :decisions)
    proposals = Map.get(state, :proposals)
    requests = Map.get(state, :requests)
    slot_out = Map.get(state, :slot_out)

    d_ready = Enum.filter(decisions, fn { slot_num, _c } -> slot_out == slot_num end)
    # find all the cmd in the decision that are ready
    if length(d_ready) > 0 do
      { _s, cmd_p } = Enum.random(d_ready)

      # there is at least 1 ready
      # find if there are any proposals at the current slot out
      prop_conflicted = Enum.filter(proposals, fn { slot_num, _c } -> slot_out == slot_num end)

      if length(prop_conflicted) > 0 do
        # there is a conflicting proposal at this current slot
        { slot_num_prop, cmd_pp } = Enum.random(prop_conflicted)
        # remove the conflicting proposal
        proposals = MapSet.delete(proposals, { slot_num_prop, cmd_pp })
        state = %{ state | proposals: proposals }

        # if the commands are different then put it in request so it will be proposed again
        if cmd_pp != cmd_p do
          requests = MapSet.put(requests, cmd_pp)
          state = %{ state | requests: requests }
          perform(state, cmd_p)
        else
          perform(state, cmd_p)
        end
      end
      # there are no conflicted proposals
      { _, cmd_p } = Enum.random(d_ready)
      perform(state, cmd_p)
    else
      # there are no decisions command ready
      propose(state)
    end
  end
end
