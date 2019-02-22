# Daniel Yung (lty16) Tim Green (tpg16)

# distributed algorithms, n.dulay 11 feb 19
# coursework 2, paxos made moderately complex

defmodule Database do

def start config, monitor do
  next config, monitor, 0, Map.new
end # start

defp next config, monitor, db_seqnum, balances do
  DAC.debug config, "D"
  receive do
    { :execute, transaction, client_num } ->
      { :move, amount, account1, account2 } = transaction
      balance1 = Map.get balances, account1, 0
      balances = Map.put balances, account1, balance1 + amount
      balance2 = Map.get balances, account2, 0
      balances = Map.put balances, account2, balance2 - amount

      send monitor, { :db_update, config.server_num, db_seqnum+1, transaction, client_num }
      next config, monitor, db_seqnum+1, balances

    _ ->
      IO.puts "Database: unexpected message"
      System.halt
  end # receive
end # next

end # Database

