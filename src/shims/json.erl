-module(json).

%% AtomVM-compatible shim for OTP 27's json module.
%% Required by gleam_json (v3) which calls json:decode/1, json:encode_integer/1 etc.
%% This is a pure Erlang re-implementation of ElixirWorkers.JSON logic,
%% adapted to the OTP json API expected by gleam_json_ffi.
%%
%% API:
%%   decode(Binary) -> Term | throws error:unexpected_end | error:{invalid_byte, Byte}
%%   encode_integer(Int) -> Binary
%%   encode_float(Float) -> Binary
%%   encode_binary(Binary) -> Binary (JSON string with quotes and escaping)

-export([decode/1, encode_integer/1, encode_float/1, encode_binary/1]).

-define(MAX_DEPTH, 32).
-define(MAX_JSON_SIZE, 10 * 1024 * 1024).

decode(Bin) when is_binary(Bin) ->
    case byte_size(Bin) > ?MAX_JSON_SIZE of
        true ->
            error(json_too_large);
        false ->
            ok
    end,
    case catch decode_value(Bin, 0, 0) of
        {'EXIT', {json_error, Reason}} ->
            % Map to OTP json errors expected by gleam_json_ffi
            case Reason of
                unexpected_end ->
                    error(unexpected_end);
                {invalid_byte, B} ->
                    error({invalid_byte, B});
                {unexpected_sequence, B} ->
                    error({unexpected_sequence, B});
                _ ->
                    error({invalid_byte, 0})
            end;
        {'EXIT', _} ->
            error({invalid_byte, 0});
        {Value, _Pos} ->
            Value;
        Value ->
            Value
    end;
decode(_) ->
    error({invalid_byte, 0}).

encode_integer(I) when is_integer(I) ->
    integer_to_binary(I).

encode_float(F) when is_float(F) ->
    % Mirrors ElixirWorkers.JSON float encoding: 6 decimals compact
    % Use erlang:float_to_binary with short
    Bin = erlang:float_to_binary(F, [short]),
    % Ensure at least one decimal point for JSON?
    % OTP's json:encode_float does similar, we just return binary
    Bin.

encode_binary(Bin) when is_binary(Bin) ->
    Escaped = escape_binary(Bin, 0, <<>>),
    <<$", Escaped/binary, $">>.

escape_binary(Bin, Pos, Acc) when Pos >= byte_size(Bin) ->
    Acc;
escape_binary(Bin, Pos, Acc) ->
    C = binary:at(Bin, Pos),
    case C of
        34 -> % "
            escape_binary(Bin, Pos + 1, <<Acc/binary, $\\, $">>);
        92 -> % \
            escape_binary(Bin, Pos + 1, <<Acc/binary, $\\, $\\>>);
        10 -> % \n
            escape_binary(Bin, Pos + 1, <<Acc/binary, $\\, $n>>);
        13 -> % \r
            escape_binary(Bin, Pos + 1, <<Acc/binary, $\\, $r>>);
        9 -> % \t
            escape_binary(Bin, Pos + 1, <<Acc/binary, $\\, $t>>);
        C when C < 32 ->
            Hex = integer_to_binary(C, 16),
            Padded =
                case byte_size(Hex) of
                    1 ->
                        <<$\\, $u, $0, $0, $0, Hex/binary>>;
                    2 ->
                        <<$\\, $u, $0, $0, Hex/binary>>;
                    _ ->
                        <<$\\, $u, $0, Hex/binary>>
                end,
            escape_binary(Bin, Pos + 1, <<Acc/binary, Padded/binary>>);
        _ ->
            escape_binary(Bin, Pos + 1, <<Acc/binary, C>>)
    end.

%% ---- Decoder internals (ported from ElixirWorkers.JSON) ----

decode_value(_Bin, _Pos, Depth) when Depth > ?MAX_DEPTH ->
    exit({json_error, {invalid_byte, 0}});
decode_value(Bin, Pos, Depth) ->
    P = skip_ws(Bin, Pos),
    case P >= byte_size(Bin) of
        true ->
            exit({json_error, unexpected_end});
        false ->
            ok
    end,
    C = binary:at(Bin, P),
    case C of
        123 -> % {
            decode_object(Bin, P + 1, Depth + 1);
        91 -> % [
            decode_array(Bin, P + 1, Depth + 1);
        34 -> % "
            decode_string(Bin, P + 1);
        116 -> % t
            {true, P + 4};
        102 -> % f
            {false, P + 5};
        110 -> % n
            {null, P + 4};
        C when C =:= 45; C >= 48, C =< 57 ->
            decode_number(Bin, P);
        _ ->
            exit({json_error, {invalid_byte, C}})
    end.

decode_object(Bin, Pos, Depth) ->
    P = skip_ws(Bin, Pos),
    case binary:at(Bin, P) of
        125 -> % }
            {#{}, P + 1};
        _ ->
            decode_pairs(Bin, P, #{}, Depth)
    end.

decode_pairs(Bin, Pos, Acc, Depth) ->
    P0 = skip_ws(Bin, Pos),
    {Key, P1} = decode_string(Bin, P0 + 1),
    P2 = skip_ws(Bin, P1),
    % expect :
    P3 = P2 + 1,
    {Value, P4} = decode_value(Bin, P3, Depth),
    NewAcc = maps:put(Key, Value, Acc),
    P5 = skip_ws(Bin, P4),
    case binary:at(Bin, P5) of
        44 -> % ,
            decode_pairs(Bin, P5 + 1, NewAcc, Depth);
        125 -> % }
            {NewAcc, P5 + 1};
        B ->
            exit({json_error, {invalid_byte, B}})
    end.

decode_array(Bin, Pos, Depth) ->
    P = skip_ws(Bin, Pos),
    case binary:at(Bin, P) of
        93 -> % ]
            {[], P + 1};
        _ ->
            decode_items(Bin, P, [], Depth)
    end.

decode_items(Bin, Pos, Acc, Depth) ->
    {Value, P1} = decode_value(Bin, Pos, Depth),
    NewAcc = [Value | Acc],
    P2 = skip_ws(Bin, P1),
    case binary:at(Bin, P2) of
        44 -> % ,
            decode_items(Bin, P2 + 1, NewAcc, Depth);
        93 -> % ]
            {lists:reverse(NewAcc), P2 + 1};
        B ->
            exit({json_error, {invalid_byte, B}})
    end.

decode_string(Bin, Pos) ->
    dec_str(Bin, Pos, []).

dec_str(Bin, Pos, Acc) ->
    C = binary:at(Bin, Pos) band 255,
    case C of
        34 -> % "
            {list_to_binary(lists:reverse(Acc)), Pos + 1};
        92 -> % \
            {Char, NewPos} = dec_esc(Bin, Pos + 1),
            dec_str(Bin, NewPos, [Char | Acc]);
        _ ->
            dec_str(Bin, Pos + 1, [C | Acc])
    end.

dec_esc(Bin, Pos) ->
    case binary:at(Bin, Pos) of
        34 ->
            {34, Pos + 1};
        92 ->
            {92, Pos + 1};
        47 ->
            {47, Pos + 1};
        110 ->
            {10, Pos + 1};
        114 ->
            {13, Pos + 1};
        116 ->
            {9, Pos + 1};
        98 ->
            {8, Pos + 1};
        102 ->
            {12, Pos + 1};
        117 ->
            dec_unicode(Bin, Pos + 1);
        B ->
            exit({json_error, {invalid_byte, B}})
    end.

dec_unicode(Bin, Pos) ->
    Hex = binary:part(Bin, Pos, 4),
    CP = hex_to_int(Hex, 0, 0),
    case CP >= 16#D800 andalso CP =< 16#DBFF of
        true ->
            case binary:at(Bin, Pos + 4) =:= 92 andalso binary:at(Bin, Pos + 5) =:= 117 of
                true ->
                    LowHex = binary:part(Bin, Pos + 6, 4),
                    Low = hex_to_int(LowHex, 0, 0),
                    Combined = 16#10000 + (CP - 16#D800) * 16#400 + (Low - 16#DC00),
                    {Combined, Pos + 10};
                false ->
                    {16#FFFD, Pos + 4}
            end;
        false ->
            {CP, Pos + 4}
    end.

hex_to_int(_Bin, 4, Acc) ->
    Acc;
hex_to_int(Bin, I, Acc) ->
    C = binary:at(Bin, I),
    Digit =
        case C of
            C when C >= 48, C =< 57 ->
                C - 48;
            C when C >= 97, C =< 102 ->
                C - 97 + 10;
            C when C >= 65, C =< 70 ->
                C - 65 + 10
        end,
    hex_to_int(Bin, I + 1, Acc * 16 + Digit).

decode_number(Bin, Pos) ->
    {Chars, EndPos, IsFloat} = collect_num(Bin, Pos, [], false),
    Str = list_to_binary(Chars),
    Value =
        case IsFloat of
            true ->
                binary_to_float(Str);
            false ->
                binary_to_integer(Str)
        end,
    {Value, EndPos}.

collect_num(Bin, Pos, Acc, IsFloat) when Pos >= byte_size(Bin) ->
    {lists:reverse(Acc), Pos, IsFloat};
collect_num(Bin, Pos, Acc, IsFloat) ->
    C = binary:at(Bin, Pos),
    case C of
        45 when Acc =:= [] ->
            collect_num(Bin, Pos + 1, [C | Acc], IsFloat);
        C when C >= 48, C =< 57 ->
            collect_num(Bin, Pos + 1, [C | Acc], IsFloat);
        46 when IsFloat =:= false ->
            collect_num(Bin, Pos + 1, [C | Acc], true);
        C when C =:= 101; C =:= 69 ->
            collect_num_exp(Bin, Pos + 1, [C | Acc]);
        _ ->
            {lists:reverse(Acc), Pos, IsFloat}
    end.

collect_num_exp(Bin, Pos, Acc) when Pos >= byte_size(Bin) ->
    {lists:reverse(Acc), Pos, true};
collect_num_exp(Bin, Pos, Acc) ->
    C = binary:at(Bin, Pos),
    case C of
        C when C =:= 43; C =:= 45 ->
            collect_num_exp_digits(Bin, Pos + 1, [C | Acc]);
        C when C >= 48, C =< 57 ->
            collect_num_exp_digits(Bin, Pos + 1, [C | Acc]);
        _ ->
            {lists:reverse(Acc), Pos, true}
    end.

collect_num_exp_digits(Bin, Pos, Acc) when Pos >= byte_size(Bin) ->
    {lists:reverse(Acc), Pos, true};
collect_num_exp_digits(Bin, Pos, Acc) ->
    C = binary:at(Bin, Pos),
    case C >= 48 andalso C =< 57 of
        true ->
            collect_num_exp_digits(Bin, Pos + 1, [C | Acc]);
        false ->
            {lists:reverse(Acc), Pos, true}
    end.

skip_ws(Bin, Pos) when Pos < byte_size(Bin) ->
    case binary:at(Bin, Pos) of
        C when C =:= 32; C =:= 9; C =:= 10; C =:= 13 ->
            skip_ws(Bin, Pos + 1);
        _ ->
            Pos
    end;
skip_ws(_Bin, Pos) ->
    Pos.
