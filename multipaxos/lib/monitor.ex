# Daniel Yung (lty16) Tim Green (tpg16)

# distributed algorithms, n.dulay 11 feb 19
# coursework 2, paxos made moderately complex

defmodule Monitor do

def start config do
  Process.send_after self(), :print, config.print_after
  next config, 0, Map.new, Map.new, Map.new, Map.new, Map.new, Map.new
end # start

defp next config, clock, requests, updates, transactions, scouts, commanders, clients do
  receive do
  { :db_update, db, seqnum, transaction, client_num } ->
    { :move, amount, from, to } = transaction

    done = Map.get updates, db, 0

    if seqnum != done + 1  do
      IO.puts "  ** error db #{db}: seq #{seqnum} expecting #{done+1}"
      System.halt
    end

    transactions =
      case Map.get transactions, seqnum do
      nil ->
        # IO.puts "db #{db} seq #{seqnum} #{done}"
        Map.put transactions, seqnum, %{ amount: amount, from: from, to: to }

      t -> # already logged - check transaction
        if amount != t.amount or from != t.from or to != t.to do
	  IO.puts " ** error db #{db}.#{done} [#{amount},#{from},#{to}] " <>
            "= log #{done}/#{map_size transactions} [#{t.amount},#{t.from},#{t.to}]"
          System.halt
        end
        transactions
      end # case

    clients_done = Map.get clients, client_num, 0
    clients = Map.put clients, client_num, clients_done + 1
    updates = Map.put updates, db, seqnum
    next config, clock, requests, updates, transactions, scouts, commanders, clients

  { :client_request, server_num } ->  # client requests seen by replicas
    seen = Map.get requests, server_num, 0
    requests = Map.put requests, server_num, seen + 1
    next config, clock, requests, updates, transactions, scouts, commanders, clients

  { :scout_spawned, server_num } -> # increment active scouts
    spawned = Map.get scouts, server_num, 0
    scouts = Map.put scouts, server_num, spawned + 1
    next config, clock, requests, updates, transactions, scouts, commanders, clients

  { :scout_finished, server_num } -> # decrement active scouts
    scouts = Map.replace! scouts, server_num, scouts[server_num] - 1
    next config, clock, requests, updates, transactions, scouts, commanders, clients

  { :commander_spawned, server_num } -> # increment active commanders
    spawned = Map.get commanders, server_num, 0
    commanders = Map.put commanders, server_num, spawned + 1
    next config, clock, requests, updates, transactions, scouts, commanders, clients

  { :commander_finished, server_num } -> # decrement active commanders
    commanders = Map.replace! commanders, server_num, commanders[server_num] - 1
    next config, clock, requests, updates, transactions, scouts, commanders, clients

  # ** ADD ADDITIONAL MESSAGES HERE

  :print ->
    clock = clock + config.print_after
    sorted = updates |> Map.to_list |> List.keysort(0)
    IO.puts "time = #{clock}  updates done = #{inspect sorted}"
    sorted = requests |> Map.to_list |> List.keysort(0)
    IO.puts "time = #{clock} requests seen = #{inspect sorted}"

    if config.debug_level == 1 do
      min_done = updates |> Map.values |> Enum.min
      n_requests = requests |> Map.values |> Enum.sum

      case config.client_send do
        :round_robin ->
          IO.puts "time = #{clock}    total seen = #{n_requests} max lag = #{n_requests - min_done}"
        :quorum ->
          IO.puts "time = #{clock}    total seen = #{n_requests} max lag = #{(div(n_requests, div(config.n_servers + 1, 2))) - min_done}"
        :broadcast ->
          IO.puts "time = #{clock}    total seen = #{n_requests} max lag = #{div(n_requests, config.n_servers) - min_done}"
      end

      sorted = scouts |> Map.to_list |> List.keysort(0)
      IO.puts "time = #{clock}        scouts = #{inspect sorted}"
      sorted = commanders |> Map.to_list |> List.keysort(0)
      IO.puts "time = #{clock}    commanders = #{inspect sorted}"

      sorted = clients |> Map.to_list |> List.keysort(0)
      IO.puts "time = #{clock}        clients = #{inspect sorted}"
    end

    IO.puts ""
    Process.send_after self(), :print, config.print_after
    next config, clock, requests, updates, transactions, scouts, commanders, clients

  _ ->
    IO.puts "monitor: unexpected message"
    System.halt
  end # receive
end # next

end # Monitor

