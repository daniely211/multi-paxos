# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Replica do
  def start(config, database, monitor) do
    state = %{
      slot_in: 1,
      slot_out: 1,
      window: 1,
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
        listen(state, config)
    end
  end

  def propose(state, config) do
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
        # get a random request
        req_arb = Enum.random(requests)
        requests = MapSet.delete(requests, req_arb)
        # add to proposal
        proposals = MapSet.put(proposals, { slot_in, req_arb })

        state = %{ state | proposals: proposals, requests: requests }
        # send the leaders this request
        for leader <- leaders, do: send leader, { :propose, slot_in, req_arb }
        state = %{ state | slot_in: slot_in + 1 }
        propose(state, config)
      else
        state = %{ state | slot_in: slot_in + 1 }
        propose(state, config)
      end
    else
      listen(state, config)
    end
  end

  def perform(state, { client, cid, op } = cmd, config) do
    slot_out = Map.get(state, :slot_out)
    decisions = Map.get(state, :decisions)


    # IO.puts "NEED TO PERFORM #{inspect cmd}, at #{inspect slot_out}, decisions are #{inspect decisions}"

    if Enum.any?(decisions, fn { s, c } -> s < slot_out and c == cmd end) do
      # IO.puts "COMMAND HAS BEEN EXECUTED AND IT IS IN THE PAST"

      state = %{ state | slot_out: slot_out + 1 }
      decisions_ready(state, config)
    else
      # IO.puts "Sending database the OP #{inspect op}"
      # TODO ATOMIC

      database = Map.get(state, :database)
      send database, { :execute, op }
      state = %{ state | slot_out: slot_out + 1 }
      # END ATOMIC
      decisions_ready(state, config)
    end
  end

  def listen(state, config) do
    receive do
      { :client_request, req } ->
        requests = Map.get(state, :requests)
        requests = MapSet.put(requests, req)
        state = %{ state | requests: requests }
        # send monitor
        monitor = Map.get(config, :monitor)
        server_num = Map.get(config, :server_num)
        # IO.puts "I AM SERVER#{inspect server_num} i got a message from client"
        send monitor, { :client_request, server_num}
        propose(state, config)

      { :decision, d_slot_no, d_cmd } ->
        # IO.puts "RECEIVED A DECISION TO DO #{inspect d_cmd}, slot num at #{inspect d_slot_no}"
        decisions = Map.get(state, :decisions)
        decisions = MapSet.put(decisions, { d_slot_no, d_cmd })
        state = %{ state | decisions: decisions }
        decisions_ready(state, config)

    end
  end

  defp decisions_ready(state, config) do
    decisions = Map.get(state, :decisions)
    proposals = Map.get(state, :proposals)
    requests = Map.get(state, :requests)
    slot_out = Map.get(state, :slot_out)

    d_ready = Enum.filter(decisions, fn { slot_num, _c } -> slot_out == slot_num end)
    # find all the cmd in the decision that are ready
    if length(d_ready) > 0 do
      # IO.puts "THERE ARE DECISIONS READY"
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
          perform(state, cmd_p, config)
        else
          perform(state, cmd_p, config)
        end
      end
      # there are no conflicted proposals
      { _, cmd_p } = Enum.random(d_ready)
      perform(state, cmd_p, config)
    else
      # there are no decisions command ready
      propose(state, config)
    end
  end
end
