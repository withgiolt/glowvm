-module(host_io).

%% Gleam WASI bridge – dual-mode.
%%   * On AtomVM (WASI) the functions below are replaced by NIFs registered
%%     in atomvm-wasi/src/platform_nifs.c as "host_io:read_stdin/0" and
%%     "host_io:write_stdout/1" (fread/fwrite, 10 MB limit, Gleam-friendly
%%     returning <<>> on empty). The BEAM bodies are never executed there.
%%   * On host (gleam run / gleam test) the NIFs are not loaded, so the
%%     Erlang bodies below run and use io:get_line/put_chars as a faithful
%%     re-implementation of the C behaviour, adapted for Gleam (<<>> on eof).
%%
%% Gleam calls this via:
%%   @external(erlang, "host_io", "read_stdin")
%%   @external(erlang, "host_io", "write_stdout")

-export([read_stdin/0, write_stdout/1]).

-define(MAX_INPUT_SIZE, 10 * 1024 * 1024).

%% NIF stub – on AtomVM this is overridden by platform_nifs.c.
%% On host it raises nif_not_loaded and we fall back to host_*.
read_stdin() ->
    try erlang:nif_error(nif_not_loaded)
    catch _:_ -> host_read_loop(<<>>)
    end.

host_read_loop(Acc) ->
    case io:get_line("") of
        eof -> Acc;
        {error, _} -> Acc;
        Data ->
            Bin = unicode:characters_to_binary(Data),
            NewAcc = <<Acc/binary, Bin/binary>>,
            case byte_size(NewAcc) > ?MAX_INPUT_SIZE of
                true -> erlang:error(json_too_large);
                false -> host_read_loop(NewAcc)
            end
    end.

write_stdout(Data) when is_binary(Data) ->
    try erlang:nif_error(nif_not_loaded)
    catch _:_ -> host_write(Data)
    end;
write_stdout(_Data) ->
    erlang:error(badarg).

host_write(Data) ->
    try io:put_chars(Data) of
        ok -> ok;
        _ -> error
    catch _:_ -> error
    end.
