-module(glowvm_bridge_ffi).

%% Validates the request tuple index.js sends before Gleam trusts its shape.
%% binary_to_term raises on malformed input; turn that and any shape mismatch
%% into an error so the bridge answers 400 instead of crashing the VM.

-export([decode_request/1]).

decode_request(Payload) ->
    try erlang:binary_to_term(Payload) of
        {Method, Url, Headers, Body} when
            is_binary(Method), is_binary(Url), is_list(Headers), is_binary(Body)
        ->
            case lists:all(fun is_header/1, Headers) of
                true -> {ok, {Method, Url, Headers, Body}};
                false -> {error, nil}
            end;
        _ ->
            {error, nil}
    catch
        _:_ -> {error, nil}
    end.

is_header({Name, Value}) -> is_binary(Name) andalso is_binary(Value);
is_header(_) -> false.
