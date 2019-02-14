
# distributed algorithms, n.dulay 11 feb 19
# coursework 2, paxos made moderately complex

defmodule Client do

def start config, client_num, replicas do
  IO.puts ["          Starting client ", DAC.node_ip_addr]
  Process.send_after self(), :client_stop, config.client_stop
  quorum =
    case config.client_send do
      :round_robin -> 1  
      :broadcast   -> config.n_servers
      :quorum      -> div config.n_servers + 1, 2
    end
  next config, client_num, replicas, 0, quorum
end # start

defp next config, client_num, replicas, sent, quorum do
  # Setting client_sleep to 0 may overload the system
  # with lots of requests and lots of spawned rocesses. 

  receive do
  :client_stop ->
    IO.puts "  Client #{client_num} going to sleep, sent = #{sent}"
    Process.sleep :infinity

  after config.client_sleep ->
    account1 = Enum.random 1 .. config.n_accounts
    account2 = Enum.random 1 .. config.n_accounts
    amount   = Enum.random 1 .. config.max_amount
    transaction  = { :move, amount, account1, account2 }

    sent = sent + 1
    cmd = { self(), sent, transaction }

    for r <- 1..quorum do
        replica = Enum.at replicas, rem(sent+r, config.n_servers)
        send replica, { :client_request, cmd }
    end

    if sent == config.max_requests, do: send self(), :client_stop

    # receive do { :reply, _cid, _result } -> :ok end
    # handle_reply()  # uncomment if replies are implemented
    next config, client_num, replicas, sent, quorum
  end
end # next

    
"""
defp handle_reply do  # discards all replies received
  receive do
  { :reply, _cid, _result } -> handle_reply()
  after 0 -> true
  end # receive
end # handle_reply 
"""

end # Client

