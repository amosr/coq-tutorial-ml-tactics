
(** We reify the structure of coq expressions as an ocaml
    data-type. We reify only the structure of the expression
    w.r.t. the [plus], [S], and [O] symbols of Coq. All other
    sub-expressions are stored in an environment.
*)
module Arith = struct
  (** First, we initialise some constants from Coq standard library.*)
  let plus = lazy (Lib_coq.init_constant ["Coq"; "Init"; "Datatypes"] "plus")
  let succ = lazy (Lib_coq.init_constant ["Coq"; "Init"; "Datatypes"] "S")
  let zero = lazy (Lib_coq.init_constant ["Coq"; "Init"; "Datatypes"] "O")

  (** [t] is an algebraic data-type that represents reified arithemtic
      expressions *)
  type t =
    | Plus of (t * t)
    | Const of int 
    | Succ of t 
    | Var of int 		       

	
  let quote env c : t =
    (** First, we force the constants, once and for all  *)
    let plus = Lazy.force plus in 
    let succ = Lazy.force succ in 
    let zero = Lazy.force zero in 
    (** Second, we decompose recursively the given term.  If the term
	is an application, we compare the head-symbol with [plus] and
	[succ]. If the term is equal to [zero], we build a
	constant. In any other case, we have to add a new variable to
	the reification environement. *)
    let rec aux c = match Coq.decomp_term c with
      | Term.App (head,args) 
	  when Term.eq_constr head plus && Array.length args = 2
	  -> Plus (aux args.(0), aux args.(1))
      | Term.App (head,args) 
	  when Term.eq_constr head succ && Array.length args =  1 
	  -> begin match (aux args.(0)) with 
	    | Const i -> Const (i +1)
	    | e -> Succ e
	  end
      | _ when Term.eq_constr c zero ->
	Const 0
      | _ ->
	let i = Lib_coq.Env.add env c in
	Var i
    in
    aux c
end


(** Now that we have reified the structure of the term inside ocaml,
    we will reify it inside Coq (this is also the purpose of the Quote
    module of standard Coq). *)

module Reif = struct
  (** We initialize a new bunch of constants that correspond to the
      constructors of our inductive. *)
  let plus = lazy (Coq.init_constant ["test"] "a_plus")
  let var = lazy (Coq.init_constant ["test"] "a_var")
  let const = lazy (Coq.init_constant ["test"] "a_const")
  let sucs = lazy (Coq.init_constant ["test"] "a_sucs")
  (** [eval] is the Coq function that maps a reified Coq arithmetic
      expression back to a nat *)
  let eval = lazy(Coq.init_consntant ["test"] "eval")

  let rec to_constr (t : Arith.t) : Term.constr =
    match t with
      | Arith.Plus (a, b) -> Term.mkApp (Lazy.force plus, [|(to_constr a); (to_constr b)|])
      | Arith.Const n -> Term.mkApp (Lazy.force const, [|Nat.of_int n|])
      | Arith.Succ a -> Term.mkApp (Lazy.force suc, [|(to_constr a)|])
      | Arith.Var n -> Term.mkApp (Lazy.force var, [|Nat.of_int n|])

  let env_to_constr (env : arith_env) : Term.constr = assert false (* Use List.of_list env *)

let reflect (env : arith_env) (t : Arith.t) : Term.constr =
    Term.mkApp (Lazy.force eval, [|env_to_constr env; to_constr t|])

let tac : Proof_type.tactic =
    fun goal => 
       let concl = Tachmach.pf_concl goal in
       match decomp_term concl with
       | Term.App(c, args) when Array.length args >= 2 ->
         let n = Array.length args in
	 let left = args.(n-2) in
	 let right = args.(n-1)
	 let r = (Term.mkApp (c, Array.sub args 0 (n - 2))) in
	 let arith_env = assert false in
	 let left' = Arith.quote arith_env left in
	 let right' = Arith.quote arith_env right in
	 let r = Term.mkApp (r, [|reflect arith_env left'; reflect arith_env right'|]) in
	    Tacticals.tclTHENLIST [Tactic.change r; Tactic.apply reflect_lemma]
	 
TACTIC EXTEND _reflect_
| ["reflect_arith"] [tac]
END
