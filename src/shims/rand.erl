-module(rand).

%% AtomVM-compatible shim for OTP's rand module.
%% AtomVM's estdlib has no rand at all, but gleam/float's random/0 is
%% `@external(erlang, "rand", "uniform")`, and gleam/int's random/1,
%% gleam/list's shuffle/1 and sample/2 all funnel through it.
%%
%% This module also lands on the *host* code path (anything under src/ does,
%% for glowvm and for every app depending on it), where it shadows OTP's rand.
%% That makes the OTP surface mandatory, not optional: kernel's
%% global_name_server calls rand:seed(default, Integer) during VM boot, and a
%% narrower module takes the whole node down with
%% `{undef,[{rand,seed,[default,_],[]}` before anything else runs. Every
%% exported function below is there for that reason — keep them.
%%
%% ponytail: the generator is xoshiro128** over four 32-bit words. AtomVM has
%% 64-bit signed integers and no bignums, so the 58-bit and 64-bit arithmetic
%% OTP's exsss/exs1024 algorithms rely on would silently overflow there;
%% xoshiro128** needs only shifts, xors and multiplication by 5 and 9, which
%% all stay well inside the range on both VMs. Good enough for shuffling and
%% sampling, not for anything cryptographic — use crypto:strong_rand_bytes/1.

-export([
    seed/1, seed/2,
    seed_s/1, seed_s/2,
    export_seed/0, export_seed_s/1,
    uniform/0, uniform/1,
    uniform_s/1, uniform_s/2,
    uniform_real/0, uniform_real_s/1,
    bytes/1, bytes_s/2,
    normal/0, normal/2,
    normal_s/1, normal_s/3,
    jump/0, jump/1
]).

-define(MASK32, 16#FFFFFFFF).
-define(DEFAULT_ALG, exsss).
%% 2^32 + 1, so uniform/0 lands strictly inside (0.0, 1.0) like OTP's.
-define(UNIFORM_DENOM, 4294967297.0).

-type word() :: 0..16#FFFFFFFF.
-type state() :: {atom(), {word(), word(), word(), word()}}.

-export_type([state/0]).

%% ---------------------------------------------------------------------------
%% Seeding
%% ---------------------------------------------------------------------------

-spec seed(atom() | state() | {atom(), term()}) -> state().
seed(AlgOrState) ->
    put_state(seed_s(AlgOrState)).

-spec seed(atom(), term()) -> state().
seed(Alg, Seed) ->
    put_state(seed_s(Alg, Seed)).

-spec seed_s(atom() | state() | {atom(), term()}) -> state().
seed_s({Alg, {_, _, _, _} = Words}) when is_atom(Alg) ->
    %% Restoring a state previously handed out by export_seed/0.
    {Alg, Words};
seed_s({Alg, Seed}) when is_atom(Alg) ->
    seed_s(Alg, Seed);
seed_s(Alg) when is_atom(Alg) ->
    {Alg, words_from_integer(fresh_entropy())};
seed_s(Seed) ->
    seed_s(?DEFAULT_ALG, Seed).

-spec seed_s(atom(), term()) -> state().
seed_s(Alg, Seed) when is_atom(Alg) ->
    {Alg, words_from_integer(seed_to_integer(Seed))}.

%% OTP accepts an integer, a {A,B,C} triple, or a previously exported state.
seed_to_integer(Int) when is_integer(Int) ->
    Int;
seed_to_integer({A, B, C}) when is_integer(A), is_integer(B), is_integer(C) ->
    mix(mix(A, B), C);
seed_to_integer({_Alg, {A, B, C, D}}) when is_integer(A) ->
    mix(mix(mix(A, B), C), D);
seed_to_integer(_Other) ->
    fresh_entropy().

-spec export_seed() -> undefined | state().
export_seed() ->
    case erlang:get(rand_seed) of
        undefined -> undefined;
        State -> export_seed_s(State)
    end.

-spec export_seed_s(state()) -> state().
export_seed_s({Alg, {_, _, _, _}} = State) when is_atom(Alg) ->
    State.

%% ---------------------------------------------------------------------------
%% Uniform
%% ---------------------------------------------------------------------------

%% Float in the open interval (0.0, 1.0).
-spec uniform() -> float().
uniform() ->
    {Value, State} = uniform_s(get_state()),
    _ = put_state(State),
    Value.

%% Integer in 1..N.
-spec uniform(pos_integer()) -> pos_integer().
uniform(N) when is_integer(N), N >= 1 ->
    {Value, State} = uniform_s(N, get_state()),
    _ = put_state(State),
    Value;
uniform(N) ->
    erlang:error(badarg, [N]).

-spec uniform_s(state()) -> {float(), state()}.
uniform_s({Alg, Words}) ->
    {X, Words1} = next(Words),
    {(X + 1) / ?UNIFORM_DENOM, {Alg, Words1}}.

-spec uniform_s(pos_integer(), state()) -> {pos_integer(), state()}.
uniform_s(N, {Alg, Words}) when is_integer(N), N >= 1 ->
    {X, Words1} = bounded(N, Words),
    {X + 1, {Alg, Words1}};
uniform_s(N, State) ->
    erlang:error(badarg, [N, State]).

-spec uniform_real() -> float().
uniform_real() ->
    uniform().

-spec uniform_real_s(state()) -> {float(), state()}.
uniform_real_s(State) ->
    uniform_s(State).

%% ---------------------------------------------------------------------------
%% Bytes
%% ---------------------------------------------------------------------------

-spec bytes(non_neg_integer()) -> binary().
bytes(N) ->
    {Bin, State} = bytes_s(N, get_state()),
    _ = put_state(State),
    Bin.

-spec bytes_s(non_neg_integer(), state()) -> {binary(), state()}.
bytes_s(N, {Alg, Words}) when is_integer(N), N >= 0 ->
    {Bin, Words1} = bytes_loop(N, Words, <<>>),
    {Bin, {Alg, Words1}}.

bytes_loop(N, Words, Acc) when N >= 4 ->
    {X, Words1} = next(Words),
    bytes_loop(N - 4, Words1, <<Acc/binary, X:32>>);
bytes_loop(0, Words, Acc) ->
    {Acc, Words};
bytes_loop(N, Words, Acc) ->
    {X, Words1} = next(Words),
    Bits = N * 8,
    Tail = X band ((1 bsl Bits) - 1),
    {<<Acc/binary, Tail:Bits>>, Words1}.

%% ---------------------------------------------------------------------------
%% Normal distribution (Box–Muller)
%% ---------------------------------------------------------------------------

-spec normal() -> float().
normal() ->
    {Value, State} = normal_s(get_state()),
    _ = put_state(State),
    Value.

-spec normal(number(), number()) -> float().
normal(Mean, Variance) ->
    {Value, State} = normal_s(Mean, Variance, get_state()),
    _ = put_state(State),
    Value.

-spec normal_s(state()) -> {float(), state()}.
normal_s(State0) ->
    {U1, State1} = uniform_s(State0),
    {U2, State2} = uniform_s(State1),
    R = math:sqrt(-2.0 * math:log(U1)),
    {R * math:cos(2.0 * math:pi() * U2), State2}.

-spec normal_s(number(), number(), state()) -> {float(), state()}.
normal_s(Mean, Variance, State0) when Variance >= 0 ->
    {Z, State1} = normal_s(State0),
    {Mean + math:sqrt(Variance) * Z, State1}.

%% ---------------------------------------------------------------------------
%% Jump
%% ---------------------------------------------------------------------------

%% We do not implement xoshiro's closed-form jump polynomial; advancing the
%% state a fixed, large number of steps gives callers the "move far away in
%% the stream" property they actually want from jump/0,1.
-spec jump() -> state().
jump() ->
    put_state(jump(get_state())).

-spec jump(state()) -> state().
jump({Alg, Words}) ->
    {Alg, advance(4096, Words)}.

advance(0, Words) ->
    Words;
advance(N, Words) ->
    {_, Words1} = next(Words),
    advance(N - 1, Words1).

%% ---------------------------------------------------------------------------
%% Process state
%% ---------------------------------------------------------------------------

get_state() ->
    case erlang:get(rand_seed) of
        {Alg, {_, _, _, _}} = State when is_atom(Alg) -> State;
        _ -> put_state(seed_s(?DEFAULT_ALG))
    end.

put_state(State) ->
    _ = erlang:put(rand_seed, State),
    State.

%% ---------------------------------------------------------------------------
%% xoshiro128**
%% ---------------------------------------------------------------------------

%% Plain xorshift128 is cheaper but its low bits are badly correlated —
%% rand:uniform(2) came out as runs of 1s and 0s. xoshiro128**'s output
%% scrambler exists to fix precisely that, and its only multiplications are by
%% 5 and 9, so the widest intermediate is under 2^36: no overflow on AtomVM.
-spec next({word(), word(), word(), word()}) -> {word(), {word(), word(), word(), word()}}.
next({S0, S1, S2, S3}) ->
    Result = (rotl(((S1 * 5) band ?MASK32), 7) * 9) band ?MASK32,
    T = (S1 bsl 9) band ?MASK32,
    S2a = S2 bxor S0,
    S3a = S3 bxor S1,
    S1a = S1 bxor S2a,
    S0a = S0 bxor S3a,
    S2b = S2a bxor T,
    S3b = rotl(S3a, 11),
    {Result, {S0a, S1a, S2b, S3b}}.

rotl(X, K) ->
    ((X bsl K) bor (X bsr (32 - K))) band ?MASK32.

%% Uniform integer in 0..N-1, rejecting the biased tail of the 32-bit range.
bounded(1, Words) ->
    {0, Words};
bounded(N, Words) when N =< ?MASK32 + 1 ->
    %% Accept only the largest multiple of N that fits in 32 bits, so every
    %% residue is equally likely.
    Limit = ((?MASK32 + 1) div N) * N - 1,
    bounded_loop(N, Limit, Words, 0);
bounded(N, Words) ->
    %% Wider than one draw: build the value from two 32-bit words. AtomVM
    %% integers are 64-bit signed, so this stays exact up to 2^62.
    {Hi, Words1} = next(Words),
    {Lo, Words2} = next(Words1),
    {((Hi bsl 30) bor (Lo bsr 2)) rem N, Words2}.

bounded_loop(N, Limit, Words, Tries) ->
    {X, Words1} = next(Words),
    case X =< Limit orelse Tries > 32 of
        true -> {X rem N, Words1};
        false -> bounded_loop(N, Limit, Words1, Tries + 1)
    end.

%% ---------------------------------------------------------------------------
%% Seed derivation
%% ---------------------------------------------------------------------------

%% Spread one integer across four non-zero 32-bit words. xorshift128 is stuck
%% at zero if every word is zero, so the constants below guarantee it isn't.
words_from_integer(Seed) ->
    S0 = Seed band 16#3FFFFFFFFFFFFFFF,
    A = scramble((S0 band ?MASK32) bxor 16#9E3779B9),
    B = scramble(((S0 bsr 32) band ?MASK32) bxor 16#85EBCA6B),
    C = scramble(A bxor 16#C2B2AE35),
    D = scramble(B bxor 16#27D4EB2F),
    Words = {A, B, C, D},
    %% Discard the first few outputs so nearby seeds diverge.
    advance(16, Words).

%% 32-bit avalanche built from shifts and xors only — no multiplication, so
%% nothing can overflow AtomVM's integers.
scramble(X0) ->
    X1 = (X0 bxor (X0 bsr 16)) band ?MASK32,
    X2 = (X1 bxor ((X1 bsl 5) band ?MASK32)) band ?MASK32,
    X3 = (X2 bxor (X2 bsr 13)) band ?MASK32,
    X4 = (X3 bxor ((X3 bsl 9) band ?MASK32)) band ?MASK32,
    case X4 of
        0 -> 16#1D872B41;
        _ -> X4
    end.

mix(A, B) ->
    ((A bsl 5) bxor B bxor (A bsr 3)) band 16#3FFFFFFFFFFFFFFF.

fresh_entropy() ->
    Time =
        try erlang:system_time(microsecond)
        catch _:_ -> 0
        end,
    Unique =
        try erlang:unique_integer()
        catch _:_ -> 0
        end,
    mix(Time, Unique).
