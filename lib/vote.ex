# Hyunjoon Jeon (hj1119)

import ExUnit.Assertions
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Vote do

# s = server process state (c.f. self/this)

# called when the election timeouts reached with no RPCs
def start_election(s, msg) do

  IO.puts "Server#{s.server_num}: election started"

  IO.puts "Server#{s.server_num}: Reason: #{inspect msg}"

  s = State.new_voted_by(s) # empty voted_by

  s = Timer.restart_election_timer(s)
  s = State.inc_term(s)
  IO.puts "Server#{inspect s.server_num}: current_term: #{inspect s.curr_term}"

  s = State.role(s,:CANDIDATE)
  IO.puts "Server#{inspect s.server_num}: current_role: #{inspect s.role}"

  s = State.voted_for(s,s.selfP) # voting for itself
  s = State.add_to_voted_by(s,s.selfP)
  IO.puts "Server#{inspect s.server_num}: number of votes: #{inspect MapSet.size(s.voted_by)}"

  #IO.puts "current server: #{inspect s.selfP}"
  msg = [s.selfP, s.server_num, Log.last_term(s), Log.last_index(s), s.curr_term] # sends process_id, last term, index of its log
  # sending each server a vote request
  for dest <- s.servers do
    if dest !== s.selfP do
      IO.puts "Server#{inspect s.server_num}: sending vote request with msg: #{inspect msg} to #{inspect dest}"
      send dest, {:VOTE_REQUEST, msg}
    end
  end
  s # return s
end

def respond_to_vote_req(s, msg) do
  from = Enum.at(msg,0)
  from_number = Enum.at(msg,1)
  requested_server_term = Enum.at(msg,4)
  IO.puts "Server#{inspect s.server_num}: vote request received from Server#{inspect from_number}"
  s = if s.curr_term < requested_server_term do # new term started
    IO.puts "Server#{inspect s.server_num}: Requested server has higher term value so increment"
    s = State.curr_term(s, requested_server_term) # update to new term
    s = State.role(s, :FOLLOWER) # server becomes follower
    assert s.role === :FOLLOWER
    IO.puts "Server#{inspect s.server_num}: this server's log last term: #{inspect Log.last_term(s)}"
    IO.puts "Server#{inspect s.server_num}: requested server's log last term: #{inspect Enum.at(msg, 2)}"
    IO.puts "Server#{inspect s.server_num}: this server's log last index: #{inspect Log.last_index(s)}"
    IO.puts "Server#{inspect s.server_num}: requested server's log last index: #{inspect Enum.at(msg,3)}"
    s = if Log.last_term(s) > Enum.at(msg, 2) do # my log has higher term
      IO.puts "Server#{inspect s.server_num}: deny Server#{inspect from_number}"
      send from, {:VOTE_REPLY, [s.selfP,s.server_num,"denied"]} # deny the vote request
      s = Timer.restart_election_timer(s)
      s #return s
    else
      s = if Log.last_term(s) === Enum.at(msg, 2) and Log.last_index(s) > Enum.at(msg, 3) do # same term but my log is longer
        IO.puts "Server#{inspect s.server_num}: deny Server#{inspect from_number}"
        send from, {:VOTE_REPLY, [s.selfP,s.server_num,"denied"]}
        s = Timer.restart_election_timer(s)
        s #return s
      else
        s = State.voted_for(s, from)
        IO.puts "Server#{inspect s.server_num}: voting for Server#{inspect from_number}"
        send from, {:VOTE_REPLY, [s.selfP,s.server_num,"ok"]}
        s = Timer.restart_election_timer(s)
        assert s.voted_for !== nil
        s #return s
      end
      s #return s
    end
    s #return s
  else
    s = if s.curr_term === requested_server_term do
      IO.puts "Server#{inspect s.server_num}: did I vote this term? Check: I voted for #{inspect s.voted_for}"
      s = if s.voted_for !== nil do # already voted so discard request
        IO.puts "Server#{inspect s.server_num}: I have already voted this term"
        s
      else
        if s.role === :CANDIDATE or s.role === :LEADER do # this server is candidate so discard vote request
          IO.puts "Server#{inspect s.server_num}: I am a #{inspect s.role} for this term so the vote request is discarded"
          s
        else
          assert s.role === :FOLLOWER
          IO.puts "Server#{inspect s.server_num}: this server's log last term: #{inspect Log.last_term(s)}"
          IO.puts "Server#{inspect s.server_num}: requested server's log last term: #{inspect Enum.at(msg, 2)}"
          IO.puts "Server#{inspect s.server_num}: this server's log last index: #{inspect Log.last_index(s)}"
          IO.puts "Server#{inspect s.server_num}: requested server's log last index: #{inspect Enum.at(msg,3)}"
          s = if Log.last_term(s) > Enum.at(msg, 2) do # my log has higher term
            IO.puts "Server#{inspect s.server_num}: deny Server#{inspect from_number}"
            send from, {:VOTE_REPLY, [s.selfP,s.server_num,"denied"]} # deny the vote request
            s = Timer.restart_election_timer(s)
            s #return s
          else
            s = if Log.last_term(s) === Enum.at(msg, 2) and Log.last_index(s) > Enum.at(msg, 3) do # same term but my log is longer
              IO.puts "Server#{inspect s.server_num}: deny Server#{inspect from_number}"
              send from, {:VOTE_REPLY, [s.selfP,s.server_num,"denied"]}
              s = Timer.restart_election_timer(s)
              s #return s
            else
              assert s.voted_for !== nil
              s = State.voted_for(s, from)
              IO.puts "Server#{inspect s.server_num}: voting for Server#{inspect from_number}"
              send from, {:VOTE_REPLY, [s.selfP,s.server_num,"ok"]}
              s = Timer.restart_election_timer(s)
              s #return s
            end
            s
          end
          s
        end
        s
      end
      s
    else
      IO.puts "Server#{inspect s.server_num}: Server that requested vote has lower term value. This server term: #{s.curr_term}, requested server term: #{requested_server_term}"
      s #return s
    end
    s #return s
  end
  s #return s
end

def respond_to_vote_reply(s, msg) do # msg contains "ok" or "denied"
  IO.puts "Server#{inspect s.server_num}: vote reply received from Server#{inspect Enum.at(msg,1)}: #{inspect Enum.at(msg,2)}"
  IO.puts "Server#{inspect s.server_num}: role: #{inspect s.role}"
  #IO.puts "#{inspect s.server_num}: majority: #{inspect s.majority}"
  s = if s.role === :LEADER do
    IO.puts "Server#{inspect s.server_num}: Already leader so vote received from Server#{inspect Enum.at(msg,1)} is discarded"
    s #return s
  else
    s = if s.role === :CANDIDATE do
      s = if Enum.at(msg,2) === "ok" do
        IO.puts "Server#{inspect s.server_num}: VOTE RECEIVED from Server#{inspect Enum.at(msg,1)}"
        #IO.puts "Server#{inspect s.server_num}: got #{inspect MapSet.size(s.voted_by)} votes BEFORE"
        s = State.add_to_voted_by(s, Enum.at(msg,0))
        #IO.puts "Server#{inspect s.server_num}: got #{inspect MapSet.size(s.voted_by)} votes AFTER"
        s = if MapSet.size(s.voted_by) >= s.majority do
          IO.puts "Server#{inspect s.server_num}: server #{inspect s.server_num} became leader"
          s = State.role(s,:LEADER)
          s = Timer.cancel_election_timer(s) # stop election timer
          s = Timer.cancel_all_append_entries_timers(s)
          #s = Timer.cancel_append_entries_timer(s, s.selfP) # stop append entries timer for itself
          #s = Timer.cancel_all_append_entries_timers(s)
          assert s.role === :LEADER
          for follower <- s.servers do
            s = if follower !== s.selfP do
              IO.puts "Server#{inspect s.server_num}: sending heartbeat to #{inspect follower}"
              data_to_send = %{success: "heartbeat", leader: s.selfP}
              send follower, {:APPEND_ENTRIES_REQUEST, data_to_send}
              #s = Timer.restart_append_entries_timer(s, follower) # send something back in 10 ms
              #s = AppendEntries.heartbeat(s)
              s #return s
            else
              s #return s
            end
            s #return s
          end
          IO.puts "Server#{s.server_num}: creating a client"
          s = ClientReq.invent_client_request(s)
          assert s.role === :LEADER
          #IO.puts "Server#{inspect s.server_num}: exiting respond to vote_reply: role: #{s.role} LINE 111"
          s # returns s
        else
          s #return s
        end
        s # return s
      end
      s # return s
    else # server is follower
      IO.puts "Server#{inspect s.server_num}: Leader has been chosen so vote reply discarded"
      #IO.puts "Server#{inspect s.server_num}: exiting respond to vote_reply: role: #{s.role} LINE 117"
      s #return s
    end
    #IO.puts "Server#{inspect s.server_num}: exiting respond to vote_reply: role: #{s.role} LINE 120"
    s #return s
  end
  #IO.puts "Server#{inspect s.server_num}: exiting respond to vote_reply: role: #{s.role} LINE 123"
  #IO.puts "DEBUGGING: #{s.server_num}"
  s # return s
end

# ... omitted

end # Vote
