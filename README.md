# dstore
A distributed key-value store written in erlang. I use this project as a playground to get some practice developing distributed systems in erlang.

# Architecture
To keep simple, every node knows about every other node. Only one dstore process can run per node. When a new dstore node starts (except the first one), it will register with the node passed to it at start-up. This information is shared to all connected dstore peer nodes, thus allowing for the sharing of information accross nodes.
