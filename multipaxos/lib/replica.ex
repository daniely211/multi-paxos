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
      { :replica_bind_leader, leaders } ->
        listen(leaders, initial_state)
    end
  end

  def propose(state) do
    window = state.window


  end

  def perform({ client, cid, op }) do

  end

  def listen(leaders, state) do
    receive do
      { :request, client} ->
        propose(leaders, MapSet.put(clients, client))

      { :decision, d_slot_no, d_cmd } ->
        decisions = Map.get(state, :decisions)
        decisions = MapSet.put(decisions, { d_slot_no, d_cmd })
        state = Map.put(state, :decisions, decisions)

        for { slot_no, com } = d <- decisions, do: process_decision(state, d)
    end

    propose(state)
  end

  defp process_decisions(state, { d_slot_no, d_com }) do
    if d_slot_no == Map.get(state, :slot_out) do
      proposals_slot_out = Enum.filter(Map.get(state, :proposal), fn { d_slot_no, p_com } ->
        # TODO: check if commands are equal
        if d_com != p_com do
          requests = Map.get(state, :requests)
          requests = MapSet.put(requests, { p_com })
          state = Map.put(state, :requests, requests)
        end
        #kinda need to remove it in the loop tho...
      end)

      # remove all the proposal that has the same Slot number
      new_proposal = MapSet.difference(Map.get(state, :proposal), proposals_slot_out)
      perform(d_com)
      for
    end
  end
end
