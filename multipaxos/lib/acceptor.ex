# Daniel Yung (lty16) Tim Green (tpg16)

defmodule Acceptor do
  def start(config) do
    listen(config, 0, MapSet.new())
  end

  def listen(config, curr_ballot, accepted) do
    receive do
      { :p1a, sender, ballot_suggest } ->
        if ballot_suggest > curr_ballot do
          send sender, { :p1b, self(), ballot_suggest, accepted }
          listen(config, ballot_suggest, accepted)
        else
          send sender, { :p1b, self(), ballot_suggest, accepted }
          listen(config, ballot_suggest, accepted)
        end

      { :p2a, sender, { ballot_suggest, _s, _c } = package} ->
        if ballot_suggest == curr_ballot do
          listen(config, curr_ballot, MapSet.put(accepted, package))
        else
          send sender, { :p2b, self(), curr_ballot }
          listen(config, curr_ballot, accepted)
        end
    end
  end
end
