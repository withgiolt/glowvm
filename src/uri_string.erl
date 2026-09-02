-module(uri_string).

%% AtomVM-compatible shim for OTP's uri_string module.
%% AtomVM's estdlib has no uri_string at all, but gleam_stdlib.erl's
%% parse_query/1 and uri_parse/1 (behind gleam/uri's parse_query and parse)
%% call straight into it. wisp's get_query/1 goes through this — proven by
%% an actual smoke-test failure (module uri_string cannot be resolved), not
%% guessed ahead of time.
%%
%% ponytail: covers RFC 3986 well enough for http(s) request URLs and query
%% strings (which is all glowvm ever feeds it) — no relative-reference
%% resolution, no IPv6 zone ids. Upgrade to the full grammar if a handler
%% needs it.

-export([dissect_query/1, parse/1]).

%% ---------------------------------------------------------------------------
%% Query strings
%% ---------------------------------------------------------------------------

-spec dissect_query(binary()) -> [{binary(), binary() | true}] | {error, atom(), term()}.
dissect_query(<<>>) ->
    [];
dissect_query(Query) when is_binary(Query) ->
    Parts = binary:split(Query, <<"&">>, [global]),
    lists:filtermap(fun
        (<<>>) -> false;
        (Part) ->
            case binary:split(Part, <<"=">>) of
                [K, V] -> {true, {percent_decode(K), percent_decode(V)}};
                [K] -> {true, {percent_decode(K), true}}
            end
    end, Parts).

%% ---------------------------------------------------------------------------
%% URIs
%% ---------------------------------------------------------------------------

-spec parse(binary()) -> map() | {error, atom(), term()}.
parse(String) when is_binary(String) ->
    case split_scheme(String) of
        {error, _, _} = E ->
            E;
        {Scheme, Rest0} ->
            {Rest1, Fragment} = split_first(Rest0, $#),
            {Rest2, Query} = split_first(Rest1, $?),
            {Authority, Path} = split_authority(Rest2),
            case Authority of
                undefined ->
                    add_optional(#{path => Path}, [
                        {scheme, Scheme}, {query, Query}, {fragment, Fragment}
                    ]);
                _ ->
                    {UserInfo, HostPort} = case binary:split(Authority, <<"@">>) of
                        [U, HP] -> {U, HP};
                        [HP] -> {undefined, HP}
                    end,
                    {Host, Port} = split_port(HostPort),
                    add_optional(#{host => Host, path => Path}, [
                        {scheme, Scheme},
                        {userinfo, UserInfo},
                        {port, Port},
                        {query, Query},
                        {fragment, Fragment}
                    ])
            end
    end.

add_optional(Map, Pairs) ->
    lists:foldl(fun
        ({_K, undefined}, Acc) -> Acc;
        ({K, V}, Acc) -> Acc#{K => V}
    end, Map, Pairs).

%% "scheme:rest" -> {<<"scheme">>, <<"rest">>}; no ':' before any '/' -> no scheme
split_scheme(Bin) ->
    case binary:split(Bin, <<":">>) of
        [Scheme, Rest] ->
            case is_scheme(Scheme) of
                true -> {Scheme, Rest};
                false -> {undefined, Bin}
            end;
        [_] ->
            {undefined, Bin}
    end.

is_scheme(<<>>) ->
    false;
is_scheme(Bin) ->
    lists:all(fun(C) ->
        (C >= $a andalso C =< $z) orelse (C >= $A andalso C =< $Z) orelse
        (C >= $0 andalso C =< $9) orelse C =:= $+ orelse C =:= $- orelse C =:= $.
    end, binary_to_list(Bin)).

%% Split on the first occurrence of Char; {Before, undefined} if absent.
split_first(Bin, Char) ->
    case binary:split(Bin, <<Char>>) of
        [Before, After] -> {Before, After};
        [Before] -> {Before, undefined}
    end.

%% "//authority/path" -> {<<"authority">>, <<"/path">>}; no "//" -> {undefined, Bin}
split_authority(<<"//", Rest/binary>>) ->
    case binary:match(Rest, <<"/">>) of
        {Pos, _} ->
            <<Authority:Pos/binary, Path/binary>> = Rest,
            {Authority, Path};
        nomatch ->
            {Rest, <<>>}
    end;
split_authority(Bin) ->
    {undefined, Bin}.

%% "host:1234" -> {<<"host">>, 1234}; "host" -> {<<"host">>, undefined}
split_port(Bin) ->
    case binary:split(Bin, <<":">>) of
        [Host, PortBin] ->
            try {Host, binary_to_integer(PortBin)}
            catch error:badarg -> {Bin, undefined}
            end;
        [Host] ->
            {Host, undefined}
    end.

%% ---------------------------------------------------------------------------
%% Percent-decoding
%% ---------------------------------------------------------------------------

percent_decode(Bin) ->
    percent_decode(Bin, <<>>).

percent_decode(<<$%, H, L, Rest/binary>>, Acc) ->
    case {hex(H), hex(L)} of
        {HV, LV} when HV =/= error, LV =/= error ->
            percent_decode(Rest, <<Acc/binary, (HV * 16 + LV)>>);
        _ ->
            percent_decode(Rest, <<Acc/binary, $%, H, L>>)
    end;
percent_decode(<<$+, Rest/binary>>, Acc) ->
    percent_decode(Rest, <<Acc/binary, $ >>);
percent_decode(<<C, Rest/binary>>, Acc) ->
    percent_decode(Rest, <<Acc/binary, C>>);
percent_decode(<<>>, Acc) ->
    Acc.

hex(C) when C >= $0, C =< $9 -> C - $0;
hex(C) when C >= $a, C =< $f -> C - $a + 10;
hex(C) when C >= $A, C =< $F -> C - $A + 10;
hex(_) -> error.
