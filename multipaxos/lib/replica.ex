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
      { :decision, slot_number, cmd } ->
        decision = Map.get(state, :decision)
        decision = MapSet.put(decision, { slot_number, cmd })
        state = Map.put(state, :decision, decision)
        # loop through decision to find a c' that has the same slot number as the cur slot_out in state
        # for each of the command with the same slot number:
          # for each of pair { slot_num, c''} in the proposals
            # remove the pair
            # check if c' == c''
              # add the c'' into request
            #
          #
          # perform(c')
    end
  end
end
