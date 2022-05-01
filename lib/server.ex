# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Server do

# s = server process state (c.f. self/this)

# _________________________________________________________ Server.start()
def start(config, server_num) do
  config = config
    |> Configuration.node_info("Server", server_num)
    |> Debug.node_starting()

  receive do
  { :BIND, servers, databaseP } ->
    State.initialise(config, server_num, servers, databaseP)
      |> Timer.restart_election_timer()
      |> Server.next()
  end # receive
end # start

# _________________________________________________________ next()
def next(s) do

  s = receive do

    { :APPEND_ENTRIES_REQUEST, msg } ->
      AppendEntries.respond_to_append_entries_request(s, msg)
      #AppendEntries.dummy(s, msg)
      # omitted

    { :APPEND_ENTRIES_REPLY, msg } ->
      AppendEntries.respond_to_append_entries_reply(s, msg)
      # omitted

    { :VOTE_REQUEST, msg } ->
      Vote.respond_to_vote_req(s, msg)
      # omitted

    { :VOTE_REPLY, msg } ->
      Vote.respond_to_vote_reply(s, msg)
      # omitted

    { :ELECTION_TIMEOUT, msg } ->
      Vote.start_election(s, msg)
      # omitted

    { :APPEND_ENTRIES_TIMEOUT, msg } ->
      Vote.start_election(s, msg)
      # omitted

    { :CLIENT_REQUEST, msg } ->
      ClientReq.command_received(s, msg)
       # omitted

    unexpected ->
      IO.puts "unexpected error occured: #{unexpected}"
      # omitted

  end # receive

  Server.next(s)

end # next

end # Server
