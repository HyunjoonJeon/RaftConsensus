# Raft Consensus

### Purpose of this project
This is a coursework for a module called "Distributed Algorithms" that I have studied at Imperial College London.
The main purpose of the project was to implement the Raft Consensus algorithm,
which consists of multiple servers that agree on a shared state and achieve a
reliable system even in the presence of failed servers. 
The structure of the system as well as key design choices can be found in the
report.docx file. 

### Files to check
I have implemented the process of leader election and  methods of appending
entries. They can be found in the following elixir files:
```
appendentries.ex
vote.ex
```
