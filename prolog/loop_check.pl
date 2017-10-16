% File: /opt/PrologMUD/pack/logicmoo_base/prolog/logicmoo/util/logicmoo_util_loop_check.pl
:- module(loop_check,
          [ is_loop_checked/1,
            lco_goal_expansion/2,            
            cyclic_break/1,

            loop_check_early/2,loop_check_term/3,
            loop_check_term/3,no_loop_check_term/3,
            
            loop_check/1,loop_check/2,no_loop_check/1,no_loop_check/2,
            current_loop_checker/1,
            push_loop_checker/0,
            pop_loop_checker/0,
            transitive/3,
            transitive_except/4,
            transitive_lc/3,
            lc_tcall/1
          ]).

:- use_module(library(apply)).


%:- use_module(library(tabling)).
:- use_module(library(each_call_cleanup)).

:- meta_predicate  
        lc_tcall(0),

        loop_check(0), loop_check(0, 0),
        no_loop_check(0), no_loop_check(0, 0),
        
        loop_check_early(0, 0), loop_check_term(0, ?, 0),

        loop_check_term(0, ?, 0),no_loop_check_term(0, ?, 0),
        
        transitive(2, +, -),
        transitive_except(+, 2, +, -),
        transitive_lc(2, +, -).
        
/* memoize_on(+,+,0), memoize_on(+,+,+,0), */


:- module_transparent
        can_fail/1,
        get_where/1,
        get_where0/1,
        is_loop_checked/1,
        lco_goal_expansion/2.
        
:- set_module(class(library)).    



%% transitive( :PRED2X, +A, -B) is nondet.
%
% Transitive.
%
transitive(X,A,B):- once(on_x_debug(call(X,A,R)) -> ( R\=@=A -> transitive_lc(X,R,B) ; B=R); B=A),!.




%% transitive_lc( :PRED2X, +A, -B) is nondet.
%
% Transitive Not Loop Checked.
%
transitive_lc(X,A,B):-transitive_except([],X,A,B).




%% transitive_except( +NotIn, :PRED2X, +A, -B) is nondet.
%
% Transitive Except.
%
transitive_except(NotIn,X,A,B):- memberchk_same_two(A,NotIn)-> (B=A,!) ;
  ((once(on_x_debug(call(X,A,R)) -> ( R\=@=A -> transitive_except([A|NotIn],X,R,B) ; B=R); B=A))),!.




%% memberchk_same_two( ?X, :TermY0) is nondet.
%
% Memberchk Same Two.
%
memberchk_same_two(X, [Y0|Ys]) :- is_list(Ys),!,C=..[v,Y0|Ys],!, arg(_,C,Y), ( X =@= Y ->  (var(X) -> X==Y ; true)),!.
memberchk_same_two(X, [Y|Ys]) :- (   X =@= Y ->  (var(X) -> X==Y ; true) ;   (nonvar(Ys),memberchk_same_two(X, Ys) )).


%% cyclic_break( ?Cyclic) is nondet.
%
% Cyclic Break.
%
cyclic_break(Cyclic):-cyclic_term(Cyclic)->(writeq(cyclic_break(Cyclic)),nl,prolog);true.


% ===================================================================
% Loop checking
% ===================================================================
:- thread_local lmcache:ilc/2.
:- thread_local lmcache:ilc/3.

% = :- meta_predicate(lc_tcall(0)).
% lc_tcall(C0):-reduce_make_key(C0,C),!,table(C),!,query(C).
% lc_tcall(C0):-query(C).



%% lc_tcall( :GoalC) is nondet.
%
% Call Tabled
%
:- meta_predicate(lc_tcall(0)).
%:- table(lc_tcall/1).
lc_tcall(G):- loop_check(call(G)).



%% loop_check_early( :Call, :LoopCaught) is nondet.
%
% Loop Check Early.
%
loop_check_early(Call, LoopCaught):- loop_check(Call, LoopCaught).



%% loop_check( :Call) is nondet.
%
% Loop Check.
%
loop_check(Call):- loop_check(Call, fail).



%% loop_check( :Call, :OnLoopCaught) is nondet.
%
% Loop Check.
%
loop_check(Call, LoopCaught):- 
  loop_check_term(Call,Call,LoopCaught).



%% no_loop_check( :Call) is nondet.
%
% No Loop Check.
%
no_loop_check(Call):- no_loop_check(Call, fail).



%% no_loop_check( :Call, :LoopCaught) is nondet.
%
% No Loop Check.
%
no_loop_check(Call, LoopCaught):- no_loop_check_term(Call,Call,LoopCaught).


%% no_loop_check_term( :Call, +Key, :LoopCaught) is nondet.
%
% Pushes a new Loop checking frame so all previous checks are suspended
%
% no_loop_check_term(Call,_Key,_LoopCaught):-!,Call.
no_loop_check_term(Call,Key,LoopCaught):- 
   trusted_redo_call_cleanup(push_loop_checker,
                     loop_check_term(Call,Key,LoopCaught),
                     pop_loop_checker).

:- nb_setval('$loop_checker',1).
:- initialization(nb_setval('$loop_checker',1),restore).
current_loop_checker(LC):- ((nb_current('$loop_checker',LC),number(LC))->true;LC=0).
push_loop_checker :- current_loop_checker(LC),LC2 is LC+1,nb_setval('$loop_checker',LC2).
pop_loop_checker :- current_loop_checker(LC),LC2 is LC-1,nb_setval('$loop_checker',LC2).


%% is_loop_checked( ?Call) is nondet.
%
% If Is A Loop Checked.
%
is_loop_checked(Key):- 
  prolog_current_frame(Frame),
  notrace(make_frame_key(Key,Frame,KeyS,GoaL,SearchFrame)),
  loop_check_term_frame(fail,KeyS,GoaL,SearchFrame,true).


make_frame_key(Key,Frame,Part1,Part2,Parent2):-
  prolog_frame_attribute(Frame,parent,Parent1),
  prolog_frame_attribute(Parent1,parent,Parent2),
  make_key(Key,Part1,Part2).

make_key(key(Part1),Part1,Part2):-!,current_loop_checker(Part2).
make_key(key(Key,GoaLs),Part1,Part2):-!,current_loop_checker(LC),make_key5(Key,GoaLs,LC,Part1,Part2).
make_key(Key,Key,Part2):- ground(Key),!,current_loop_checker(Part2).
make_key(Key,Part1,Part2):- copy_term(Key,KeyS,GoaLs),current_loop_checker(LC),make_key5(KeyS,GoaLs,LC,Part1,Part2).

make_key5(Part1,[],LC,Part1,LC):-!,numbervars(Part1,242,_,[attvar(error)]).
make_key5(Part1,GoaLs,LC,Part1,[LC|GoaLs]):-numbervars(Part1+GoaLs,242,_,[attvar(error)]).


     

loop_check_term_frame(Call,KeyS,GoaL,SearchFrame,LoopCaught):- 
   notrace(prolog_frame_attribute(SearchFrame,parent_goal,
      loop_check_term_frame(_,KeyS,GoaL,_,_)))
    -> LoopCaught 
    ;  Call.



%% loop_check_term( :Call, +Key, :LoopCaught) is nondet.
%
% Loop Check Term 50% of the time
%
loop_check_term(Call,_Key,_LoopCaught):- notrace((current_prolog_flag(unsafe_speedups , true) , 1 is random(2))),!,call(Call).
% loop_check_term(Call,_Key,_LoopCaught):-!,Call.

loop_check_term(Call,Key,LoopCaught):- 
   prolog_current_frame(Frame),
   notrace(make_frame_key(Key,Frame,KeyS,GoaL,SearchFrame)),
   loop_check_term_frame(Call,KeyS,GoaL,SearchFrame,LoopCaught).


%% get_where( :TermB) is nondet.
%
% Get Where.
%
get_where(B:L):-get_where0(F:L),file_base_name(F,B).


%% get_where0( :GoalF) is nondet.
%
% Get Where Primary Helper.
%
get_where0(F:L):-source_location(file,F),current_input(S),line_position(S,L),!.
get_where0(F:L):-source_location(F,L),!.
get_where0(A:0):-current_input(S),stream_property(S,alias(A)),!.
get_where0(M:0):-source_context_module(M),!.
get_where0(baseKB:0):-!.




%% lco_goal_expansion( :TermB, :TermA) is nondet.
%
% Lco Call Expansion.
%

lco_goal_expansion(V,VV):- \+ compound(V),!,V=VV.
lco_goal_expansion(loop_check(G),O):-!,lco_goal_expansion(loop_check(G,fail),O).
lco_goal_expansion(no_loop_check(G),O):-!,lco_goal_expansion(no_loop_check(G,fail),O).
lco_goal_expansion(loop_check(G,LoopCaught),loop_check_term(G,info(G,W),LoopCaught)):- get_where(W).
lco_goal_expansion(no_loop_check(G,LoopCaught),no_loop_check_term(G,info(G,W),LoopCaught)):- get_where(W).
lco_goal_expansion(B,A):- 
  compound_name_arguments(B,F,ARGS),
  F \== (meta_predicate),
  maplist(lco_goal_expansion,ARGS,AARGS),
  compound_name_arguments(A,F,AARGS).
lco_goal_expansion(A,A).

:- fixup_exports.

:- multifile system:goal_expansion/4.
:- dynamic system:goal_expansion/4.
system:goal_expansion(LC,Pos,LCO,Pos):- compound(LC),lco_goal_expansion(LC,LCO)->LC\=@=LCO.


end_of_file.

Old stuff


/*

make_key(Key0,M,lmcache:ilc(M,Key,GoaL)):- var(Key0),!,copy_term(Key0,Key,GoaL),numbervars(Key+GoaL,242,_,[attvar(error)]).
make_key(key(Key),M,lmcache:ilc(M,Key)):- !.
make_key(nat(Key0),M,lmcache:ilc(M,Key)):- !, copy_term_nat(Key0,Key),numbervars(Key,242,_,[attvar(error)]).
make_key(Key,M,lmcache:ilc(M,Key)):- ground(Key),!.
make_key(Key0,M,lmcache:ilc(M,Key,GoaL)):- copy_term(Key0,Key,GoaL),numbervars(Key+GoaL,242,_,[attvar(error)]).

old_loop_check_term(Call,Key0,LoopCaught):- strip_module(Call,M,_),
   quietly(make_key(Key0,M,Key)),!,
   (Key -> ((LoopCaught)) ; M:locally_each(Key,Call)).


loop_check_term(Call,Key,LoopCaught):- 
  current_loop_checker(Trie) ,
  (trie_lookup(Trie, Key, Value),Value==1) -> LoopCaught ;
    each_call_cleanup(trie_insert(Trie, Key, 1),Call,trie_insert(Trie, Key, 0)).
*/

