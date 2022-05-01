# Hyunjoon Jeon (hj1119)

import ExUnit.Assertions
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule ClientReq do

# s = server process state (c.f. self/this)

# command received from client
def command_received(s, msg) do
  initial_size = map_size(s.log)
  s = if s.role === :LEADER do
    IO.puts "Server#{s.server_num}: command received"
    # client message :CLIENT_REQUEST
    # %{clientP: c.clientP, cid: cid, cmd: cmd }
    IO.puts "Server#{s.server_num}: adding to leader's log: Term: #{inspect s.curr_term}, Index: #{map_size(s.log)+1}, Request: #{inspect msg.cmd}"
    s = Log.append_entry(s, %{term: s.curr_term, index: map_size(s.log)+1, request: msg.cmd}) # added new request
    s = AppendEntries.fix_log_inconsistencies(s)
    assert initial_size < map_size(s.log)
    s #return s
  else
    s #return s
  end
  #IO.puts "DEBUGGING: log size = #{map_size(s.log)}"
  assert s !== nil
  s #return s
end

def invent_client_request(s) do
  assert s.role === :LEADER
  data_to_send = %{clientP: "test_client_process", cid: "test_client_id", cmd: "y<-3"}
  IO.puts "Server#{s.server_num}: sending a command"
  send s.selfP, {:CLIENT_REQUEST, data_to_send}
  s #return s
end

# omitted

end # Clientreq
