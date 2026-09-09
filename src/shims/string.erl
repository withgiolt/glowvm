-module(string).

%% AtomVM-compatible shim for OTP's string module, replacing AtomVM's estdlib
%% string.erl (which this module must stand in for, so it is dropped from the
%% estdlib set copied into priv/stdlib — two modules of the same name in one
%% PackBeam is undefined behaviour).
%%
%% AtomVM's version only ever grew the handful of functions AtomVM itself
%% needed, and it is charlist-oriented: string:trim/2 pattern-matches on
%% [$\s | R], so handing it the binary Gleam actually passes falls through the
%% catch-all and returns the string *unchanged*. That is why string.trim_start
%% looked like it worked while string.trim and string.trim_end crashed in
%% lists:reverse/1 — a wrong answer and a crash from the same root cause.
%% Missing outright: lowercase/1, uppercase/1, reverse/1, equal/2, is_empty/1,
%% next_grapheme/1, slice/3, replace/4 and pad/4, which between them account
%% for most of the commented-out lines in fixtures/app/src/stdlib_string.gleam
%% and stdlib_string_tree.gleam.
%%
%% This module also joins the *host* code path and shadows OTP's string, so it
%% implements OTP's surface rather than just Gleam's — including the legacy
%% list API. OTP's own io_lib calls string:length/1, string:slice/3,
%% string:is_empty/1 and string:next_grapheme/1 while formatting, so gaps here
%% surface as mangled output rather than a clean crash.
%%
%% ponytail: grapheme clusters are approximated as codepoints. Real clustering
%% needs unicode_util, a ~10k-line generated table that would dwarf the rest of
%% a bundle; the two agree for everything except combining marks, emoji ZWJ
%% sequences and Hangul jamo. Case mapping covers ASCII, Latin-1, Latin
%% Extended-A, Greek and Cyrillic — one-to-one mappings only, so no sharp-s to
%% SS. Both limits are documented alongside AtomVM's own in the README.

-export([
    %% Modern (chardata) API
    equal/2, equal/3, equal/4,
    length/1,
    to_graphemes/1,
    reverse/1,
    slice/2, slice/3,
    pad/2, pad/3, pad/4,
    trim/1, trim/2, trim/3,
    chomp/1,
    take/2, take/3, take/4,
    lexemes/2, nth_lexeme/3,
    uppercase/1, lowercase/1, titlecase/1, casefold/1,
    to_integer/1, to_float/1,
    prefix/2,
    split/2, split/3,
    replace/3, replace/4,
    find/2, find/3,
    next_grapheme/1, next_codepoint/1,
    is_empty/1,
    concat/2,
    span/2, cspan/2,
    jaro_similarity/2,
    %% Legacy list API, still exported by OTP
    len/1,
    to_upper/1, to_lower/1,
    join/2,
    tokens/2,
    strip/1, strip/2, strip/3,
    chr/2, rchr/2, str/2, rstr/2,
    substr/2, substr/3,
    sub_string/2, sub_string/3,
    chars/2, chars/3,
    copies/2,
    words/1, words/2,
    sub_word/2, sub_word/3,
    left/2, left/3,
    right/2, right/3,
    centre/2, centre/3
]).

%% Unicode Pattern_White_Space, the set Gleam's string.trim documents.
-define(WHITESPACE, [9, 10, 11, 12, 13, 32, 133, 8206, 8207, 8232, 8233]).

%%=============================================================================
%% Chardata plumbing
%%
%% Everything below normalises its input to a list of codepoints, does the work
%% there, and converts back to the *shape it was given*: binary in, binary out.
%% That is not cosmetic. gleam_stdlib:contains_string/2 is
%% `is_bitstring(string:find(String, Substring))`, so a find/2 that answered a
%% list for binary input would report "not found" for every substring that is
%% in fact present.
%%=============================================================================

%% @private
cps(CD) ->
    case unicode:characters_to_list(CD) of
        L when is_list(L) -> L;
        _ -> error(badarg, [CD])
    end.

%% @private
cps_opt(CD) ->
    case unicode:characters_to_list(CD) of
        L when is_list(L) -> {ok, L};
        _ -> error
    end.

%% @private
%% StringTrees and io_lib's deep lists arrive as lists; only a bare binary asks
%% for a binary back.
wants_binary(CD) -> is_binary(CD).

%% @private
out(Cps, true) -> unicode:characters_to_binary(Cps);
out(Cps, false) -> Cps.

%%=============================================================================
%% Comparison and size
%%=============================================================================

-spec equal(A :: unicode:chardata(), B :: unicode:chardata()) -> boolean().
equal(A, B) ->
    cps(A) =:= cps(B).

-spec equal(unicode:chardata(), unicode:chardata(), boolean()) -> boolean().
equal(A, B, false) ->
    equal(A, B);
equal(A, B, true) ->
    lowercase_cps(cps(A)) =:= lowercase_cps(cps(B)).

%% Normalisation forms need unicode_util; we accept the argument and compare
%% case-folded, which is right for any already-normalised input.
-spec equal(unicode:chardata(), unicode:chardata(), boolean(), atom()) -> boolean().
equal(A, B, IgnoreCase, _Norm) ->
    equal(A, B, IgnoreCase).

-spec length(String :: unicode:chardata()) -> non_neg_integer().
length(String) ->
    erlang:length(cps(String)).

-spec is_empty(String :: unicode:chardata()) -> boolean().
is_empty(String) ->
    cps(String) =:= [].

%%=============================================================================
%% Traversal
%%=============================================================================

-spec to_graphemes(String :: unicode:chardata()) -> [char()].
to_graphemes(String) ->
    cps(String).

-spec next_grapheme(String :: unicode:chardata()) ->
    maybe_improper_list(char(), unicode:chardata()) | {error, unicode:chardata()}.
next_grapheme(String) ->
    next_codepoint(String).

-spec next_codepoint(String :: unicode:chardata()) ->
    maybe_improper_list(char(), unicode:chardata()) | {error, unicode:chardata()}.
next_codepoint(String) ->
    case cps_opt(String) of
        {ok, []} -> [];
        {ok, [C | Rest]} -> [C | out(Rest, wants_binary(String))];
        error -> {error, String}
    end.

-spec reverse(String :: unicode:chardata()) -> unicode:chardata().
reverse(String) ->
    out(lists:reverse(cps(String)), wants_binary(String)).

%%=============================================================================
%% Case
%%=============================================================================

-spec uppercase(String :: unicode:chardata()) -> unicode:chardata().
uppercase(String) ->
    out([upper_char(C) || C <- cps(String)], wants_binary(String)).

-spec lowercase(String :: unicode:chardata()) -> unicode:chardata().
lowercase(String) ->
    out(lowercase_cps(cps(String)), wants_binary(String)).

-spec casefold(String :: unicode:chardata()) -> unicode:chardata().
casefold(String) ->
    lowercase(String).

-spec titlecase(String :: unicode:chardata()) -> unicode:chardata().
titlecase(String) ->
    case cps(String) of
        [] -> out([], wants_binary(String));
        [C | Rest] -> out([upper_char(C) | Rest], wants_binary(String))
    end.

%% @private
lowercase_cps(Cps) ->
    [lower_char(C) || C <- Cps].

%% @private
%% One-to-one mappings for ASCII, Latin-1, Latin Extended-A, Greek and
%% Cyrillic. Anything outside those blocks is passed through unchanged.
upper_char(C) when C >= $a, C =< $z -> C - 32;
upper_char(C) when C >= 16#E0, C =< 16#FE, C =/= 16#F7 -> C - 32;
upper_char(16#FF) -> 16#178;
upper_char(C) when C >= 16#100, C =< 16#137, C band 1 =:= 1 -> C - 1;
upper_char(C) when C >= 16#139, C =< 16#148, C band 1 =:= 0 -> C - 1;
upper_char(C) when C >= 16#14A, C =< 16#177, C band 1 =:= 1 -> C - 1;
upper_char(C) when C >= 16#179, C =< 16#17E, C band 1 =:= 0 -> C - 1;
upper_char(16#3C2) -> 16#3A3;
upper_char(C) when C >= 16#3B1, C =< 16#3CB -> C - 32;
upper_char(C) when C >= 16#430, C =< 16#44F -> C - 32;
upper_char(C) when C >= 16#450, C =< 16#45F -> C - 80;
upper_char(C) -> C.

%% @private
lower_char(C) when C >= $A, C =< $Z -> C + 32;
lower_char(C) when C >= 16#C0, C =< 16#DE, C =/= 16#D7 -> C + 32;
lower_char(16#178) -> 16#FF;
lower_char(C) when C >= 16#100, C =< 16#137, C band 1 =:= 0 -> C + 1;
lower_char(C) when C >= 16#139, C =< 16#148, C band 1 =:= 1 -> C + 1;
lower_char(C) when C >= 16#14A, C =< 16#177, C band 1 =:= 0 -> C + 1;
lower_char(C) when C >= 16#179, C =< 16#17E, C band 1 =:= 1 -> C + 1;
lower_char(C) when C >= 16#391, C =< 16#3AB -> C + 32;
lower_char(C) when C >= 16#410, C =< 16#42F -> C + 32;
lower_char(C) when C >= 16#400, C =< 16#40F -> C + 80;
lower_char(C) -> C.

%%=============================================================================
%% Slicing and padding
%%=============================================================================

-spec slice(String :: unicode:chardata(), Start :: non_neg_integer()) -> unicode:chardata().
slice(String, Start) ->
    slice(String, Start, infinity).

-spec slice(
    String :: unicode:chardata(),
    Start :: non_neg_integer(),
    Length :: non_neg_integer() | infinity
) -> unicode:chardata().
slice(String, Start, Length) when is_integer(Start), Start >= 0 ->
    Dropped = drop_n(cps(String), Start),
    Taken =
        case Length of
            infinity -> Dropped;
            _ when is_integer(Length), Length >= 0 -> take_n(Dropped, Length);
            _ -> error(badarg, [String, Start, Length])
        end,
    out(Taken, wants_binary(String));
slice(String, Start, Length) ->
    error(badarg, [String, Start, Length]).

%% @private
drop_n(Cps, 0) -> Cps;
drop_n([], _N) -> [];
drop_n([_ | Rest], N) -> drop_n(Rest, N - 1).

%% @private
take_n(_Cps, 0) -> [];
take_n([], _N) -> [];
take_n([C | Rest], N) -> [C | take_n(Rest, N - 1)].

-spec pad(unicode:chardata(), non_neg_integer()) -> unicode:chardata().
pad(String, Length) ->
    pad(String, Length, trailing, $\s).

-spec pad(unicode:chardata(), non_neg_integer(), leading | trailing | both) -> unicode:chardata().
pad(String, Length, Dir) ->
    pad(String, Length, Dir, $\s).

-spec pad(
    unicode:chardata(),
    non_neg_integer(),
    leading | trailing | both,
    char() | [char()]
) -> unicode:chardata().
pad(String, Length, Dir, Char) ->
    Cps = cps(String),
    Fill = pad_char(Char),
    Missing = Length - erlang:length(Cps),
    Padded =
        case Missing =< 0 of
            true ->
                Cps;
            false ->
                case Dir of
                    leading ->
                        lists:duplicate(Missing, Fill) ++ Cps;
                    trailing ->
                        Cps ++ lists:duplicate(Missing, Fill);
                    both ->
                        Left = Missing div 2,
                        lists:duplicate(Left, Fill) ++ Cps ++
                            lists:duplicate(Missing - Left, Fill)
                end
        end,
    out(Padded, wants_binary(String)).

%% @private
pad_char(C) when is_integer(C) -> C;
pad_char([C | _]) when is_integer(C) -> C;
pad_char(Bin) when is_binary(Bin) -> hd(cps(Bin));
pad_char(_) -> $\s.

%%=============================================================================
%% Trimming
%%=============================================================================

-spec trim(String :: unicode:chardata()) -> unicode:chardata().
trim(String) ->
    trim(String, both, ?WHITESPACE).

-spec trim(String :: unicode:chardata(), Dir :: leading | trailing | both) ->
    unicode:chardata().
trim(String, Dir) ->
    trim(String, Dir, ?WHITESPACE).

-spec trim(
    String :: unicode:chardata(),
    Dir :: leading | trailing | both,
    Characters :: [char()] | unicode:chardata()
) -> unicode:chardata().
trim(String, Dir, Characters) ->
    Set = char_set(Characters),
    Cps = cps(String),
    Trimmed =
        case Dir of
            leading -> triml(Cps, Set);
            trailing -> lists:reverse(triml(lists:reverse(Cps), Set));
            both -> lists:reverse(triml(lists:reverse(triml(Cps, Set)), Set))
        end,
    out(Trimmed, wants_binary(String)).

%% @private
triml([C | Rest] = Cps, Set) ->
    case lists:member(C, Set) of
        true -> triml(Rest, Set);
        false -> Cps
    end;
triml([], _Set) ->
    [].

%% @private
%% Accepts a codepoint list, a binary, or a list of one-character strings.
char_set(Characters) when is_list(Characters) ->
    lists:flatmap(
        fun
            (C) when is_integer(C) -> [C];
            (Other) -> cps(Other)
        end,
        Characters
    );
char_set(Characters) ->
    cps(Characters).

-spec chomp(String :: unicode:chardata()) -> unicode:chardata().
chomp(String) ->
    Chomped =
        case lists:reverse(cps(String)) of
            [$\n, $\r | Rest] -> lists:reverse(Rest);
            [$\n | Rest] -> lists:reverse(Rest);
            [$\r | Rest] -> lists:reverse(Rest);
            Reversed -> lists:reverse(Reversed)
        end,
    out(Chomped, wants_binary(String)).

%%=============================================================================
%% Searching
%%=============================================================================

-spec find(String :: unicode:chardata(), SearchPattern :: unicode:chardata()) ->
    unicode:chardata() | nomatch.
find(String, SearchPattern) ->
    find(String, SearchPattern, leading).

-spec find(
    String :: unicode:chardata(),
    SearchPattern :: unicode:chardata(),
    Direction :: leading | trailing
) -> unicode:chardata() | nomatch.
find(String, SearchPattern, Direction) ->
    Cps = cps(String),
    case cps(SearchPattern) of
        [] ->
            String;
        Pattern ->
            Bin = wants_binary(String),
            case match_at(Cps, Pattern, Direction) of
                nomatch -> nomatch;
                Index -> out(drop_n(Cps, Index), Bin)
            end
    end.

%% @private
%% Index of the first (or last) occurrence of Pattern in Cps, or nomatch.
match_at(Cps, Pattern, leading) ->
    match_forward(Cps, Pattern, 0);
match_at(Cps, Pattern, trailing) ->
    match_backward(Cps, Pattern, 0, nomatch).

%% @private
match_forward([], _Pattern, _Index) ->
    nomatch;
match_forward([_ | Rest] = Cps, Pattern, Index) ->
    case is_prefix(Cps, Pattern) of
        true -> Index;
        false -> match_forward(Rest, Pattern, Index + 1)
    end.

%% @private
match_backward([], _Pattern, _Index, Best) ->
    Best;
match_backward([_ | Rest] = Cps, Pattern, Index, Best) ->
    Best1 =
        case is_prefix(Cps, Pattern) of
            true -> Index;
            false -> Best
        end,
    match_backward(Rest, Pattern, Index + 1, Best1).

%% @private
is_prefix(_Cps, []) -> true;
is_prefix([C | Cps], [C | Pattern]) -> is_prefix(Cps, Pattern);
is_prefix(_Cps, _Pattern) -> false.

-spec prefix(String :: unicode:chardata(), Prefix :: unicode:chardata()) ->
    nomatch | unicode:chardata().
prefix(String, Prefix) ->
    Cps = cps(String),
    Pattern = cps(Prefix),
    case is_prefix(Cps, Pattern) of
        true -> out(drop_n(Cps, erlang:length(Pattern)), wants_binary(String));
        false -> nomatch
    end.

-spec span(String :: unicode:chardata(), Characters :: [char()]) -> non_neg_integer().
span(String, Characters) ->
    span_count(cps(String), char_set(Characters), false, 0).

-spec cspan(String :: unicode:chardata(), Characters :: [char()]) -> non_neg_integer().
cspan(String, Characters) ->
    span_count(cps(String), char_set(Characters), true, 0).

%% @private
span_count([], _Set, _Complement, N) ->
    N;
span_count([C | Rest], Set, Complement, N) ->
    case lists:member(C, Set) =/= Complement of
        true -> span_count(Rest, Set, Complement, N + 1);
        false -> N
    end.

-spec take(unicode:chardata(), [char()]) -> {unicode:chardata(), unicode:chardata()}.
take(String, Characters) ->
    take(String, Characters, false, leading).

-spec take(unicode:chardata(), [char()], boolean()) ->
    {unicode:chardata(), unicode:chardata()}.
take(String, Characters, Complement) ->
    take(String, Characters, Complement, leading).

-spec take(unicode:chardata(), [char()], boolean(), leading | trailing) ->
    {unicode:chardata(), unicode:chardata()}.
take(String, Characters, Complement, Dir) ->
    Cps = cps(String),
    Set = char_set(Characters),
    Bin = wants_binary(String),
    case Dir of
        leading ->
            N = span_count(Cps, Set, Complement, 0),
            {out(take_n(Cps, N), Bin), out(drop_n(Cps, N), Bin)};
        trailing ->
            N = span_count(lists:reverse(Cps), Set, Complement, 0),
            Split = erlang:length(Cps) - N,
            {out(take_n(Cps, Split), Bin), out(drop_n(Cps, Split), Bin)}
    end.

%%=============================================================================
%% Splitting and replacing
%%=============================================================================

-spec split(String :: unicode:chardata(), SearchPattern :: unicode:chardata()) ->
    [unicode:chardata()].
split(String, SearchPattern) ->
    split(String, SearchPattern, leading).

-spec split(
    String :: unicode:chardata(),
    SearchPattern :: unicode:chardata(),
    Where :: leading | trailing | all
) -> [unicode:chardata()].
split(String, SearchPattern, Where) ->
    Bin = wants_binary(String),
    Cps = cps(String),
    case cps(SearchPattern) of
        [] ->
            [out(Cps, Bin)];
        Pattern ->
            [out(Part, Bin) || Part <- split_cps(Cps, Pattern, Where)]
    end.

%% @private
split_cps(Cps, Pattern, all) ->
    split_all(Cps, Pattern, erlang:length(Pattern), []);
split_cps(Cps, Pattern, Where) ->
    case match_at(Cps, Pattern, Where) of
        nomatch ->
            [Cps];
        Index ->
            [take_n(Cps, Index), drop_n(Cps, Index + erlang:length(Pattern))]
    end.

%% @private
split_all(Cps, Pattern, PatternLen, Acc) ->
    case match_at(Cps, Pattern, leading) of
        nomatch ->
            lists:reverse([Cps | Acc]);
        Index ->
            split_all(
                drop_n(Cps, Index + PatternLen), Pattern, PatternLen, [take_n(Cps, Index) | Acc]
            )
    end.

-spec replace(unicode:chardata(), unicode:chardata(), unicode:chardata()) ->
    [unicode:chardata()].
replace(String, SearchPattern, Replacement) ->
    replace(String, SearchPattern, Replacement, leading).

-spec replace(
    unicode:chardata(),
    unicode:chardata(),
    unicode:chardata(),
    leading | trailing | all
) -> [unicode:chardata()].
replace(String, SearchPattern, Replacement, Where) ->
    %% OTP returns chardata with the replacement spliced between the parts,
    %% not a flattened string; gleam_stdlib:string_replace/3 hands the result
    %% straight to a StringTree, which is chardata too.
    lists:join(Replacement, split(String, SearchPattern, Where)).

-spec lexemes(String :: unicode:chardata(), SeparatorList :: [char()]) ->
    [unicode:chardata()].
lexemes(String, SeparatorList) ->
    Set = char_set(SeparatorList),
    Bin = wants_binary(String),
    [out(Part, Bin) || Part <- lexemes_cps(cps(String), Set, [], []), Part =/= []].

%% @private
lexemes_cps([], _Set, Current, Acc) ->
    lists:reverse([lists:reverse(Current) | Acc]);
lexemes_cps([C | Rest], Set, Current, Acc) ->
    case lists:member(C, Set) of
        true -> lexemes_cps(Rest, Set, [], [lists:reverse(Current) | Acc]);
        false -> lexemes_cps(Rest, Set, [C | Current], Acc)
    end.

-spec nth_lexeme(unicode:chardata(), pos_integer(), [char()]) -> unicode:chardata().
nth_lexeme(String, N, SeparatorList) when is_integer(N), N >= 1 ->
    case drop_n(lexemes(String, SeparatorList), N - 1) of
        [Lexeme | _] -> Lexeme;
        [] -> error(badarg, [String, N, SeparatorList])
    end.

-spec concat(unicode:chardata(), unicode:chardata()) -> unicode:chardata().
concat(A, B) ->
    Cps = cps(A) ++ cps(B),
    out(Cps, wants_binary(A) andalso wants_binary(B)).

%%=============================================================================
%% Numbers
%%=============================================================================

-spec to_integer(unicode:chardata()) ->
    {integer(), unicode:chardata()} | {error, no_integer | badarg}.
to_integer(String) ->
    Bin = wants_binary(String),
    Cps = cps(String),
    {DigitsRev, Rest} = scan_integer(Cps),
    case lists:reverse(DigitsRev) of
        [] -> {error, no_integer};
        "-" -> {error, no_integer};
        "+" -> {error, no_integer};
        Digits -> {erlang:list_to_integer(Digits), out(Rest, Bin)}
    end.

%% @private
scan_integer([Sign | Rest]) when Sign =:= $-; Sign =:= $+ ->
    scan_digits(Rest, [Sign]);
scan_integer(Cps) ->
    scan_digits(Cps, []).

%% @private
scan_digits([C | Rest], Acc) when C >= $0, C =< $9 ->
    scan_digits(Rest, [C | Acc]);
scan_digits(Cps, Acc) ->
    {Acc, Cps}.

-spec to_float(unicode:chardata()) ->
    {float(), unicode:chardata()} | {error, no_float | badarg}.
to_float(String) ->
    Bin = wants_binary(String),
    Cps = cps(String),
    case scan_float(Cps) of
        error -> {error, no_float};
        {Chars, Rest} -> {erlang:list_to_float(Chars), out(Rest, Bin)}
    end.

%% @private
%% Erlang floats need digits on both sides of the point, so "1." is not one.
scan_float(Cps0) ->
    {SignRev, Cps1} =
        case Cps0 of
            [Sign | R] when Sign =:= $-; Sign =:= $+ -> {[Sign], R};
            _ -> {[], Cps0}
        end,
    {IntRev, Cps2} = scan_digits(Cps1, []),
    case {IntRev, Cps2} of
        {[], _} ->
            error;
        {_, [$. | Cps3]} ->
            case scan_digits(Cps3, []) of
                {[], _} ->
                    error;
                {FracRev, Cps4} ->
                    {ExpRev, Cps5} = scan_exponent(Cps4),
                    {lists:reverse(ExpRev ++ FracRev ++ [$. | IntRev] ++ SignRev), Cps5}
            end;
        _ ->
            error
    end.

%% @private
scan_exponent([E | Rest0]) when E =:= $e; E =:= $E ->
    {SignRev, Rest1} =
        case Rest0 of
            [Sign | R] when Sign =:= $-; Sign =:= $+ -> {[Sign], R};
            _ -> {[], Rest0}
        end,
    case scan_digits(Rest1, []) of
        {[], _} -> {[], [E | Rest0]};
        {DigitsRev, Rest2} -> {DigitsRev ++ SignRev ++ [E], Rest2}
    end;
scan_exponent(Cps) ->
    {[], Cps}.

%%=============================================================================
%% Jaro similarity
%%=============================================================================

%% AtomVM's estdlib ships a stub that always answers 0.0; this is the real
%% thing, so anything that scores candidate strings gets usable numbers.
-spec jaro_similarity(unicode:chardata(), unicode:chardata()) -> float().
jaro_similarity(String1, String2) ->
    A = cps(String1),
    B = cps(String2),
    LenA = erlang:length(A),
    LenB = erlang:length(B),
    case {LenA, LenB} of
        {0, 0} ->
            1.0;
        {0, _} ->
            0.0;
        {_, 0} ->
            0.0;
        _ ->
            Window = erlang:max(erlang:max(LenA, LenB) div 2 - 1, 0),
            {Matches, MatchedA, MatchedB} = jaro_matches(A, B, Window, LenB),
            case Matches of
                0 ->
                    0.0;
                _ ->
                    Transpositions = jaro_transpositions(MatchedA, MatchedB),
                    M = float(Matches),
                    (M / LenA + M / LenB + (M - Transpositions / 2) / M) / 3
            end
    end.

%% @private
jaro_matches(A, B, Window, LenB) ->
    jaro_matches(A, B, Window, LenB, 0, 0, [], []).

%% @private
jaro_matches([], _B, _Window, _LenB, _Index, Matches, MatchedA, MatchedB) ->
    {Matches, lists:reverse(MatchedA), lists:reverse(MatchedB)};
jaro_matches([C | Rest], B, Window, LenB, Index, Matches, MatchedA, MatchedB) ->
    Low = erlang:max(0, Index - Window),
    High = erlang:min(LenB - 1, Index + Window),
    case jaro_find(C, B, Low, High) of
        nomatch ->
            jaro_matches(Rest, B, Window, LenB, Index + 1, Matches, MatchedA, MatchedB);
        {At, B1} ->
            jaro_matches(
                Rest, B1, Window, LenB, Index + 1, Matches + 1, [C | MatchedA], [{At, C} | MatchedB]
            )
    end.

%% @private
%% Consumes the matched position in B by replacing it with a sentinel, so no
%% character is matched twice.
jaro_find(C, B, Low, High) ->
    jaro_find(C, B, Low, High, 0, []).

%% @private
jaro_find(_C, [], _Low, _High, _Index, _Seen) ->
    nomatch;
jaro_find(C, [C | Rest], Low, High, Index, Seen) when Index >= Low, Index =< High ->
    {Index, lists:reverse(Seen) ++ [nomatch | Rest]};
jaro_find(C, [Other | Rest], Low, High, Index, Seen) ->
    jaro_find(C, Rest, Low, High, Index + 1, [Other | Seen]).

%% @private
jaro_transpositions(MatchedA, MatchedB) ->
    InBOrder = [C || {_At, C} <- lists:keysort(1, MatchedB)],
    erlang:length([x || {X, Y} <- lists:zip(MatchedA, InBOrder), X =/= Y]).

%%=============================================================================
%% Legacy list API
%%
%% Deprecated in OTP but still exported, so it stays here: this module shadows
%% OTP's, and anything still calling string:tokens/2 or string:strip/1 would
%% otherwise get an undef.
%%=============================================================================

-spec len(unicode:chardata()) -> non_neg_integer().
len(String) -> string:length(String).

-spec to_upper(string() | char()) -> string() | char().
to_upper(C) when is_integer(C) -> upper_char(C);
to_upper(String) when is_binary(String) -> uppercase(String);
to_upper(String) -> [upper_char(C) || C <- String].

-spec to_lower(string() | char()) -> string() | char().
to_lower(C) when is_integer(C) -> lower_char(C);
to_lower(String) when is_binary(String) -> lowercase(String);
to_lower(String) -> [lower_char(C) || C <- String].

-spec join([string()], string()) -> string().
join(Strings, Separator) ->
    lists:flatten(lists:join(Separator, Strings)).

-spec tokens(string(), string()) -> [string()].
tokens(String, SeparatorList) ->
    [Token || Token <- lexemes_cps(cps(String), char_set(SeparatorList), [], []), Token =/= []].

-spec strip(string()) -> string().
strip(String) -> strip(String, both, $\s).

-spec strip(string(), left | right | both) -> string().
strip(String, Dir) -> strip(String, Dir, $\s).

-spec strip(string(), left | right | both, char()) -> string().
strip(String, left, Char) -> trim(String, leading, [Char]);
strip(String, right, Char) -> trim(String, trailing, [Char]);
strip(String, both, Char) -> trim(String, both, [Char]).

-spec chr(string(), char()) -> non_neg_integer().
chr(String, Char) -> index_of(cps(String), Char, 1).

%% @private
index_of([], _Char, _Index) -> 0;
index_of([Char | _Rest], Char, Index) -> Index;
index_of([_ | Rest], Char, Index) -> index_of(Rest, Char, Index + 1).

-spec rchr(string(), char()) -> non_neg_integer().
rchr(String, Char) ->
    Cps = cps(String),
    case index_of(lists:reverse(Cps), Char, 1) of
        0 -> 0;
        FromEnd -> erlang:length(Cps) - FromEnd + 1
    end.

-spec str(string(), string()) -> non_neg_integer().
str(String, SubString) ->
    case match_at(cps(String), cps(SubString), leading) of
        nomatch -> 0;
        Index -> Index + 1
    end.

-spec rstr(string(), string()) -> non_neg_integer().
rstr(String, SubString) ->
    case match_at(cps(String), cps(SubString), trailing) of
        nomatch -> 0;
        Index -> Index + 1
    end.

-spec substr(string(), pos_integer()) -> string().
substr(String, Start) -> slice(String, Start - 1).

-spec substr(string(), pos_integer(), non_neg_integer()) -> string().
substr(String, Start, Length) -> slice(String, Start - 1, Length).

-spec sub_string(string(), pos_integer()) -> string().
sub_string(String, Start) -> substr(String, Start).

-spec sub_string(string(), pos_integer(), pos_integer()) -> string().
sub_string(String, Start, Stop) -> substr(String, Start, Stop - Start + 1).

-spec chars(char(), non_neg_integer()) -> string().
chars(Char, N) -> chars(Char, N, []).

-spec chars(char(), non_neg_integer(), string()) -> string().
chars(Char, N, Tail) -> lists:duplicate(N, Char) ++ Tail.

-spec copies(string(), non_neg_integer()) -> string().
copies(String, N) -> lists:append(lists:duplicate(N, String)).

-spec words(string()) -> pos_integer().
words(String) -> words(String, $\s).

-spec words(string(), char()) -> pos_integer().
words(String, Char) -> erlang:length(tokens(String, [Char])).

-spec sub_word(string(), integer()) -> string().
sub_word(String, N) -> sub_word(String, N, $\s).

-spec sub_word(string(), integer(), char()) -> string().
sub_word(String, N, Char) when N >= 1 ->
    case drop_n(tokens(String, [Char]), N - 1) of
        [Word | _] -> Word;
        [] -> []
    end;
sub_word(_String, _N, _Char) ->
    [].

-spec left(string(), non_neg_integer()) -> string().
left(String, Number) -> left(String, Number, $\s).

-spec left(string(), non_neg_integer(), char()) -> string().
left(String, Number, Char) ->
    Cps = cps(String),
    case erlang:length(Cps) >= Number of
        true -> take_n(Cps, Number);
        false -> pad(Cps, Number, trailing, Char)
    end.

-spec right(string(), non_neg_integer()) -> string().
right(String, Number) -> right(String, Number, $\s).

-spec right(string(), non_neg_integer(), char()) -> string().
right(String, Number, Char) ->
    Cps = cps(String),
    Len = erlang:length(Cps),
    case Len >= Number of
        true -> drop_n(Cps, Len - Number);
        false -> pad(Cps, Number, leading, Char)
    end.

-spec centre(string(), non_neg_integer()) -> string().
centre(String, Number) -> centre(String, Number, $\s).

-spec centre(string(), non_neg_integer(), char()) -> string().
centre(_String, 0, _Char) ->
    [];
centre(String, Number, Char) ->
    Cps = cps(String),
    Len = erlang:length(Cps),
    case Len >= Number of
        true -> take_n(drop_n(Cps, (Len - Number) div 2), Number);
        false -> pad(Cps, Number, both, Char)
    end.
