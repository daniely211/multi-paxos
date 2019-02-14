
# distributed algorithms, n.dulay, 11 feb 19
# helper functions v2

defmodule DAC do

# ---------------------
def node_ip_addr do
  {:ok, interfaces} = :inet.getif()		# get interfaces
  {address, _gateway, _mask}  = hd interfaces	# get data for 1st interface
  {a, b, c, d} = address   			# get octets for address
  "#{a}.#{b}.#{c}.#{d}"
end

def lookup name do
  addresses = :inet_res.lookup name, :in, :a 
  {a, b, c, d} = hd addresses   # get octets for 1st ipv4 address
  :"#{a}.#{b}.#{c}.#{d}"
end

# ---------------------
def node_name config, name, n do
  case config.setup do
  :single -> 	# return local elixir node
    node() 		
  :docker -> 	# return node address for docker container
    :'#{name}#{n}@#{name}#{n}.localdomain' 
  end
end

def node_spawn node, module, function, args do
  if Node.connect node do
    Process.sleep 5   	# in case Node needs time to load modules
    Node.spawn node, module, function, args
  else 
    Process.sleep 100	# retry in 100ms
    node_spawn node, module, function, args 
  end
end

# ---------------------
def debug config, info do
  if config.debug_level == 3, do: IO.write info
end

# ---------------------
def adler32(x),           do: :erlang.adler32(x)
def unzip3(triples),      do: :lists.unzip3 triples
# ---------------------

def get_config do
  # get version of configuration given by 1st arg
  config = Configuration.version :'#{Enum.at System.argv, 0}'

  # add type of setup (single | docker)
  config = Map.put config, :setup, :'#{Enum.at System.argv, 1}'

  # add number of servers and clients 
  config = Map.put config, :n_servers, String.to_integer(Enum.at System.argv, 2)
  config = Map.put config, :n_clients, String.to_integer(Enum.at System.argv, 3) 
  config
end

end # module -----------------------


