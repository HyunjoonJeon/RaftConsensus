# Hyunjoon Jeon (hj1119)

import ExUnit.Assertions
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do

# s = server process state (c.f. this/self)

def dummy(s, msg) do #dummy for heartbeat check
  s = if msg.success === "heartbeat" do
    IO.puts "Server#{s.server_num}: heartbeat received from the leader"
    s = State.role(s,:FOLLOWER)
    s = State.leaderP(s, msg.leader)
    s = Timer.cancel_election_timer(s)
    #s = Timer.cancel_append_entries_timer(s, s.leaderP)
    IO.puts "Server#{s.server_num}: server role: #{s.role}"
    data_to_send = %{success: "heartbeat", followerP: s.selfP}
    IO.puts "Server#{s.server_num}: sending heartbeat reply to leader"
    send s.leaderP, {:APPEND_ENTRIES_REPLY, data_to_send}
    s = Timer.restart_append_entries_timer(s, s.selfP)
    #s = Timer.restart_append_entries_timer(s, s.selfP)
    #s = Timer.restart_append_entries_timer(s, s.leaderP)
    s #return s
  else
    s #return s
  end
  s #return s
end

def heartbeat(s) do
  assert s.role === :LEADER
  assert s.election_timer === nil
  #assert s.append_entries_timers[s.selfP] === nil
  #s = Timer.cancel_append_entries_timer(s, s.selfP)
  for follower <- s.servers do
    if follower !== s.selfP do
      data_to_send = %{success: "heartbeat", leader: s.selfP}
      IO.puts "Server#{inspect s.server_num}: sending heartbeat to #{inspect follower}"
      send follower, {:APPEND_ENTRIES_REQUEST, data_to_send}
      #s = Timer.restart_append_entries_timer(s, follower)
    end
    s
  end
  s
end

# check for log inconsistencies
# assumed to be only called by leader
# initial APPEND_ENTRIES_REQUEST to be sent to followers
def fix_log_inconsistencies(s) do
  IO.puts "Server#{s.server_num}: Leader sends APPEND_ENTRIES_REQUEST for followers to replicate leader's log"
  # send <index, term> of previous entry + <term, command> of new entry
  #s = Timer.cancel_append_entries_timer(s, s.selfP)
  for follower <- s.servers do
    s = if follower !== s.selfP do
      # assuming new request already appended to leader's log
      #new_entry = Log.entry_at(s, map_size(s.log))
      range = 1..1
      new_entry = Log.get_entries(s, range)
      #new_entries = [%{index: map_size(s.log), term: s.curr_term, request: msg.cmd}] # assumes client request stored in msg
      #old_entry = %{index: s.log[map_size(s.log)-1].index, term: s.log[map_size(s.log)-1].term}
      old_entry = if map_size(s.log) > 1 do
        %{index: s.log[map_size(s.log)-1].index, term: s.log[map_size(s.log)-1].term} # last entry index and term
      else
        nil
      end
      IO.puts "Server#{s.server_num}: sending new_entry = #{inspect new_entry}, old_entry = #{inspect old_entry}"
      data_to_send = %{success: "append", leader: s.selfP, new_entry: new_entry, old_entry: old_entry}
      send follower, {:APPEND_ENTRIES_REQUEST, data_to_send}
      #s = Timer.restart_append_entries_timer(s, follower)
      s #return s
    else
      s #return s
    end
    s #return s
  end
  s #return s
end

# induction step
def respond_to_append_entries_reply(s, msg) do
  follower = msg.followerP
  #s = Timer.cancel_append_entries_timer(s, s.selfP)
  if msg.success === "heartbeat" do
    Process.sleep(2) #sleep 2ms
    IO.puts "Server#{inspect s.server_num}: sending heartbeat to #{inspect follower}"
    data_to_send = %{success: "heartbeat", leader: s.selfP}
    send msg.followerP, {:APPEND_ENTRIES_REQUEST, data_to_send}
    #s = Timer.restart_append_entries_timer(s, msg.followerP) # restart append entries timer
  end
  s = if msg.success === "consistent" do # assumes that the follower successfully replicated leader's log
    assert msg.last_index === map_size(s.log)
    # write down match index
    s = State.match_index(s, follower, map_size(s.log))
    IO.puts "Server#{s.server_num}: log replicated: #{inspect s.match_index}"
    #for match <- s.match_index do

    #end
    s #return s
  else
    s = if msg.success === "inconsistent" do
      IO.puts "Server#{s.server_num}: log inconsistent: RETRY"
      # retry with lower log index
      range = Log.entry_at(s, msg.old_entry_index).index..map_size(s.log)
      new_entry = Log.get_entries(s, range)
      # 1 step before attempted old_entry
      old_entry = %{index: Log.entry_at(s, msg.old_entry_index-1).index, term: Log.entry_at(s, msg.old_entry_index-1).term}
      #IO.puts "DEBUGGING: new_entry = #{inspect new_entry}, old_entry = #{inspect old_entry}"
      data = {:APPEND_ENTRIES_REQUEST, %{success: "append", leader: s.selfP, new_entry: new_entry, old_entry: old_entry}}
      send follower, {:APPEND_ENTRIES_REQUEST, data}
      #s = Timer.restart_append_entries_timer(s, follower)
      s #return s
    else
      if msg.success !== "heartbeat" do
        IO.puts "ERROR: invalid value in append_entries_reply: #{msg.success}"
      end
      s #return s
    end
    s #return s
  end
  s #return s
end

# received APPEND_ENTRIES_REQUEST
def respond_to_append_entries_request(s, msg) do
  s = Timer.restart_append_entries_timer(s, s.selfP)
  IO.puts "Server#{s.server_num}: received APPEND_ENTRIES_REQUEST from leader: Server#{inspect msg.leader}"
  s = Timer.cancel_election_timer(s)
  s = State.leaderP(s, msg.leader)
  s = State.role(s, :FOLLOWER)
  assert s.leaderP === msg.leader
  assert s.role === :FOLLOWER
  s = if msg.success === "heartbeat" do
    # send back message so the leader can send heartbeat again
    data_to_send = %{success: "heartbeat", followerP: s.selfP}
    send s.leaderP, {:APPEND_ENTRIES_REPLY, data_to_send}
    #s = Timer.cancel_append_entries_timer(s, s.leaderP)
    #s = Timer.restart_append_entries_timer(s, s.selfP)
    s
  else # msg.success === "append"
    # compare if entry at given index matches
    IO.puts "Server#{s.server_num}: checking for log consistency"
    s = if msg.old_entry !== nil do
      s = if Log.entry_at(s, msg.old_entry.index).term === msg.old_entry.term do # log is consistent
        IO.puts "Server#{s.server_num}: log is consistent"
        s = Log.delete_entries_from(s, msg.old_entry.index + 1)
        s = Log.merge_entries(s, msg.new_entry)
        IO.puts "Server#{s.server_num}: replicated log #{inspect s.log}"
        data_to_send = %{followerP: s.selfP, success: "consistent", last_index: map_size(s.log)}
        send s.leaderP, {:APPEND_ENTRIES_REPLY, data_to_send}
        s #return s
      else # log is inconsistent
        IO.puts "Server#{s.server_num}: log is inconsistent"
        data_to_send = %{followerP: s.selfP, success: "inconsistent", old_entry_index: msg.old_entry.index}
        send s.leaderP, {:APPEND_ENTRIES_REPLY, data_to_send}
        s #return s
      end
      s #return s
    else # msg.old_entry === nil
      assert map_size(s.log) === 0
      s = Log.merge_entries(s, msg.new_entry)
      IO.puts "Server#{s.server_num}: replicated log #{inspect s.log}"
      data_to_send = %{followerP: s.selfP, success: "consistent", last_index: map_size(s.log)}
      send s.leaderP, {:APPEND_ENTRIES_REPLY, data_to_send}
      s #return s
    end
    s #return s
  end
  s #return s
end

# checks if majority server succeeded in replicating a request
def commit(s) do
  #s.commit_index
  #s.last_applied
  #s.match_index # initially empty
end

 # ... omitted

end # AppendEntriess
