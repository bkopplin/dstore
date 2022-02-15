-module(dstore).

-export([start/0, start/1, lookup/2, insert/3, stop/1, init/0, init/1, peers/1, data/1]).

%%
%% Client Functions 
%%
start() ->
	Pid = spawn(dstore, init, []),
	register(dstore, Pid).

start(KnownNode) ->
	Pid = spawn(dstore, init, [KnownNode]),
	register(dstore, Pid).
	

lookup(Node, Key) ->
	{dstore, Node} ! {client, self(), lookup, Key},
	receive {res, Result} -> Result end.

insert(Node, Key, Data) ->
	{dstore, Node} ! {client, self(), insert, Key, Data},
	receive {res, Result} -> Result end.

peers(Node) ->
	{dstore, Node} ! {debug, self(), peers},
	receive {res, Result} -> Result end.

data(Node) ->
	{dstore, Node} ! {debug, self(), data},
	receive {res, Result} -> Result end.


stop(_Node) ->
	ok.

%%
%% Server Functions
%%

init() -> 
	io:format("Started dstore ~w - ~s~n", [self(), node()]),
	loop([],[]).

init(KnownNode) ->
	io:format("Started dstore ~w - ~s~n", [self(), node()]),
	{dstore, KnownNode} ! {peer, self(), register},
	receive {res, Sender, OtherPids} -> 
			io:format("received from ~w other Pids ~w~n", [Sender, OtherPids]),
			loop([Sender|OtherPids], []) end.

-spec loop(Peers :: [pid()], Data :: [{any(), any()}]) -> none().

loop(Peers, Data) ->
	receive
		{client, Sender, lookup, Key} ->
			io:format("received lookup request from ~w~n", [Sender]),
			Result = lists:keyfind(Key, 1, Data),
			Sender ! {res, Result},
			loop(Peers, Data);
		{client, Sender, insert, Key, Value} ->
			io:format("received insert request from ~w~n", [Sender]),
			NewData = [{Key, Value}|Data],
			lists:foreach(fun(P) -> P ! {peer, insert, Key, Value} end, Peers),
			Sender ! {res, ok},
			loop(Peers, NewData);
		{peer, Sender, register} ->
			io:format("[~w] register node ~w~n", [self(), Sender]),
			case lists:member(Sender, Peers) of 
				true ->
					loop(Peers, Data);
				false ->
					lists:foreach(fun(P) -> P ! {peer, newnode, Sender} end, Peers),
					Sender ! {res, self(), Peers},
					loop([Sender|Peers], Data)
			end;
		{peer, register, NewPid} when NewPid =:= self() -> 
			loop(Peers, Data);
		{peer, register, NewPid} ->
			case lists:member(NewPid, Peers) of
				true ->
					loop(Peers, Data);
				false ->
					io:format("[~w] new node ~w~n", [self(), NewPid]),
					erlang:monitor_node(node(NewPid)),
					loop([NewPid|Peers], Data)
			end;
		{peer, insert, Key, Value} ->
			case lists:keyfind(Key, 1, Data) of
				true ->
					NewData = [{Key,Value}|lists:keydelete(Key, 1, Data)],
					loop(Peers, NewData);
				false ->
					loop(Peers, [{Key,Value}|Data])
			end;
		{debug, Sender, peers} ->
			Sender ! {res, Peers},
			loop(Peers, Data);
		{debug, Sender, data} ->
			Sender ! {res, Data},
			loop(Peers, Data);
		{nodedown, Node} ->
			io:format("Node down: ~s~n", [Node]),
			erlang:monitor_node(Node, false).


	end.
