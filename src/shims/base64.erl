-module(base64).

%% AtomVM-compatible shim for OTP's base64 module.
%%
%% AtomVM's base64:encode/1 and base64:decode/1 (no options) are backed by a
%% real NIF and work fine as-is. But gleam_stdlib:base64_encode/2 (behind
%% gleam/bit_array's base64_encode/2, and base64_url_encode/2 which is built
%% on top of it) calls base64:encode/2 with an options map for padding — and
%% on AtomVM that arity has no NIF behind it, only the estdlib source's
%% `erlang:nif_error(undefined)` stub. Confirmed empirically: catching the
%% call showed `error:undef`, not a crash inside real encoding logic.
%%
%% This module also joins the *host* code path and shadows OTP's base64, so it
%% is a full pure-Erlang implementation rather than a partial one that leans
%% on the arity-1 NIF for some calls and not others — one code path behaves
%% identically on both VMs, which is easier to trust than two.

-export([
    encode/1, encode/2,
    decode/1, decode/2,
    encode_to_string/1, encode_to_string/2,
    decode_to_string/1, decode_to_string/2,
    mime_decode/1, mime_decode/2,
    mime_decode_to_string/1, mime_decode_to_string/2
]).

-define(TABLE_STD, <<"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/">>).
-define(TABLE_URL, <<"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_">>).

%%=============================================================================
%% Encoding
%%=============================================================================

-spec encode(iodata()) -> binary().
encode(Data) ->
    encode(Data, #{}).

-spec encode(iodata(), #{padding => boolean(), mode => standard | urlsafe}) -> binary().
encode(Data, Options) when is_map(Options) ->
    Bin = iolist_to_binary(Data),
    Padding = maps:get(padding, Options, true),
    Table = table_for(maps:get(mode, Options, standard)),
    encode_bin(Bin, Table, Padding).

-spec encode_to_string(iodata()) -> string().
encode_to_string(Data) ->
    encode_to_string(Data, #{}).

-spec encode_to_string(iodata(), #{padding => boolean(), mode => standard | urlsafe}) -> string().
encode_to_string(Data, Options) ->
    binary_to_list(encode(Data, Options)).

%% @private
encode_bin(Bin, Table, Padding) ->
    Groups = encode_groups(Bin, Table, <<>>),
    case Padding of
        true -> Groups;
        false -> strip_padding(Groups)
    end.

%% @private
%% Encodes three bytes -> four base64 characters at a time, padding the final
%% short group with zero bits (RFC 4648 §4) and `=' characters.
encode_groups(<<A, B, C, Rest/binary>>, Table, Acc) ->
    encode_groups(Rest, Table, <<Acc/binary, (encode_triple(A, B, C, Table))/binary>>);
encode_groups(<<A, B>>, Table, Acc) ->
    <<C1, C2, C3, _>> = encode_triple(A, B, 0, Table),
    <<Acc/binary, C1, C2, C3, $=>>;
encode_groups(<<A>>, Table, Acc) ->
    <<C1, C2, _, _>> = encode_triple(A, 0, 0, Table),
    <<Acc/binary, C1, C2, $=, $=>>;
encode_groups(<<>>, _Table, Acc) ->
    Acc.

%% @private
encode_triple(A, B, C, Table) ->
    N = (A bsl 16) bor (B bsl 8) bor C,
    <<(binary:at(Table, (N bsr 18) band 16#3F)), (binary:at(Table, (N bsr 12) band 16#3F)),
        (binary:at(Table, (N bsr 6) band 16#3F)), (binary:at(Table, N band 16#3F))>>.

%% @private
strip_padding(Bin) ->
    case binary:last(Bin) of
        $= -> strip_padding(binary:part(Bin, 0, byte_size(Bin) - 1));
        _ -> Bin
    end.

%% @private
table_for(standard) -> ?TABLE_STD;
table_for(urlsafe) -> ?TABLE_URL.

%%=============================================================================
%% Decoding
%%=============================================================================

-spec decode(iodata()) -> binary().
decode(Data) ->
    decode(Data, #{}).

-spec decode(iodata(), #{padding => boolean(), mode => standard | urlsafe}) -> binary().
decode(Data, Options) when is_map(Options) ->
    Bin = strip_ws(iolist_to_binary(Data)),
    Mode = maps:get(mode, Options, standard),
    RequirePadding = maps:get(padding, Options, true),
    decode_bin(Bin, Mode, RequirePadding).

-spec decode_to_string(iodata()) -> string().
decode_to_string(Data) ->
    decode_to_string(Data, #{}).

-spec decode_to_string(iodata(), #{padding => boolean(), mode => standard | urlsafe}) -> string().
decode_to_string(Data, Options) ->
    binary_to_list(decode(Data, Options)).

%% RFC 2045 MIME decoding (ignores characters outside the alphabet, e.g. line
%% breaks) instead of RFC 4648 strict decoding (anything unexpected is
%% badarg). AtomVM ships neither; both are cheap once decode_bin exists.
-spec mime_decode(iodata()) -> binary().
mime_decode(Data) ->
    mime_decode(Data, #{}).

-spec mime_decode(iodata(), #{mode => standard | urlsafe}) -> binary().
mime_decode(Data, Options) when is_map(Options) ->
    Bin = iolist_to_binary(Data),
    Mode = maps:get(mode, Options, standard),
    Alphabet = table_for(Mode),
    Cleaned = <<<<C>> || <<C>> <= Bin, (is_alphabet_char(C, Alphabet) orelse C =:= $=)>>,
    decode_bin(Cleaned, Mode, false).

-spec mime_decode_to_string(iodata()) -> string().
mime_decode_to_string(Data) ->
    binary_to_list(mime_decode(Data)).

-spec mime_decode_to_string(iodata(), #{mode => standard | urlsafe}) -> string().
mime_decode_to_string(Data, Options) ->
    binary_to_list(mime_decode(Data, Options)).

%% @private
is_alphabet_char(C, Alphabet) ->
    binary:match(Alphabet, <<C>>) =/= nomatch.

%% @private
strip_ws(Bin) ->
    <<<<C>> || <<C>> <= Bin, C =/= $\s, C =/= $\t, C =/= $\r, C =/= $\n>>.

%% @private
decode_bin(<<>>, _Mode, _RequirePadding) ->
    <<>>;
decode_bin(Bin, Mode, RequirePadding) ->
    Padded =
        case {byte_size(Bin) rem 4, RequirePadding} of
            {0, _} ->
                Bin;
            {_, true} ->
                error(badarg, [Bin]);
            {N, false} ->
                <<Bin/binary, (binary:copy(<<$=>>, 4 - N))/binary>>
        end,
    Table = table_for(Mode),
    decode_groups(Padded, Table, <<>>).

%% @private
decode_groups(<<C1, C2, $=, $=, Rest/binary>>, Table, Acc) ->
    N = (index_of(C1, Table) bsl 18) bor (index_of(C2, Table) bsl 12),
    A = (N bsr 16) band 16#FF,
    decode_groups(Rest, Table, <<Acc/binary, A>>);
decode_groups(<<C1, C2, C3, $=, Rest/binary>>, Table, Acc) ->
    N =
        (index_of(C1, Table) bsl 18) bor (index_of(C2, Table) bsl 12) bor
            (index_of(C3, Table) bsl 6),
    A = (N bsr 16) band 16#FF,
    B = (N bsr 8) band 16#FF,
    decode_groups(Rest, Table, <<Acc/binary, A, B>>);
decode_groups(<<C1, C2, C3, C4, Rest/binary>>, Table, Acc) ->
    N =
        (index_of(C1, Table) bsl 18) bor (index_of(C2, Table) bsl 12) bor
            (index_of(C3, Table) bsl 6) bor index_of(C4, Table),
    A = (N bsr 16) band 16#FF,
    B = (N bsr 8) band 16#FF,
    C = N band 16#FF,
    decode_groups(Rest, Table, <<Acc/binary, A, B, C>>);
decode_groups(<<>>, _Table, Acc) ->
    Acc;
decode_groups(Rest, _Table, _Acc) ->
    error(badarg, [Rest]).

%% @private
index_of(C, Table) ->
    case binary:match(Table, <<C>>) of
        {Pos, 1} -> Pos;
        nomatch -> error(badarg, [C])
    end.
