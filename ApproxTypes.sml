(*  Celf
 *  Copyright (C) 2008 Anders Schack-Nielsen and Carsten Sch�rmann
 *
 *  This file is part of Celf.
 *
 *  Celf is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Celf is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Celf.  If not, see <http://www.gnu.org/licenses/>.
 *)

signature TLU_ApproxTypes = TOP_LEVEL_UTIL
structure ApproxTypes :> APPROXTYPES =
struct

open Syntax
open Context
open PatternBind

val traceApx = ref false

type context = apxAsyncType Context.context

exception ExnApxUnifyType of string

(* ucase : string -> bool *)
fun ucase x = (*x<>"" andalso Char.isUpper (String.sub (x, 0))*)
	let fun ucase' [] = false
		  | ucase' (c::cs) = Char.isUpper c orelse (c = #"_" andalso ucase' cs)
	in ucase' (String.explode x) end

(* occur : typeLogicVar -> apxAsyncType -> unit *)
fun occur X = foldApxType {fki = ignore, fsTy = ignore, faTy =
	(fn ApxTLogicVar X' => if eqLVar (X, X') then raise ExnApxUnifyType "Occurs check" else ()
	  | _ => ()) }

(* apxUnifyType : apxAsyncType * apxAsyncType -> unit *)
fun apxUnifyType (ty1, ty2) = case (Util.apxTypePrjAbbrev ty1, Util.apxTypePrjAbbrev ty2) of
	  (ApxLolli (A1, B1), ApxLolli (A2, B2)) => (apxUnifySyncType (A1, A2); apxUnifyType (B1, B2))
	| (ApxAddProd (A1, B1), ApxAddProd (A2, B2)) => (apxUnifyType (A1, A2); apxUnifyType (B1, B2))
	| (ApxTMonad S1, ApxTMonad S2) => apxUnifySyncType (S1, S2)
	| (ApxTAtomic a1, ApxTAtomic a2) =>
			if a1 = a2 then () else raise ExnApxUnifyType (a1^" and "^a2^" differ")
	| (ApxTLogicVar X, A as ApxTLogicVar X') =>
			if eqLVar (X, X') then () else updLVar (X, ApxAsyncType.inj A)
	| (ApxTLogicVar X, _) => (occur X ty2; updLVar (X, ty2))
	| (_, ApxTLogicVar X) => (occur X ty1; updLVar (X, ty1))
	| (A1, A2) => raise ExnApxUnifyType
			(PrettyPrint.printType (unsafeCast ty1)^"\nand: "
						^PrettyPrint.printType (unsafeCast ty2))
and apxUnifySyncType (ty1, ty2) = case (ApxSyncType.prj ty1, ApxSyncType.prj ty2) of
	  (ApxTTensor (S1, T1), ApxTTensor (S2, T2)) =>
			(apxUnifySyncType (S1, S2); apxUnifySyncType (T1, T2))
	| (ApxTOne, ApxTOne) => ()
	| (ApxTDown A1, ApxTDown A2) => apxUnifyType (A1, A2)
	| (ApxTAffi A1, ApxTAffi A2) => apxUnifyType (A1, A2)
	| (ApxTBang A1, ApxTBang A2) => apxUnifyType (A1, A2)
	| (S1, S2) => raise ExnApxUnifyType
			(PrettyPrint.printType (unsafeCast (ApxTMonad' ty1))^"\nand: "
						^PrettyPrint.printType (unsafeCast (ApxTMonad' ty2)))

fun apxUnify (ty1, ty2, errmsg) = (apxUnifyType (ty1, ty2))
		handle (e as ExnApxUnifyType s) =>
			( print ("ExnApxUnify: "^s^"\n")
			; print $ errmsg ()
			; raise e)

val apxCount = ref 0

(* apxInferPattern : pattern -> apxSyncType *)
fun apxInferPattern p = case Pattern.prj p of
	  PDepTensor (p1, p2) => ApxTTensor' (apxInferPattern p1, apxInferPattern p2)
	| POne => ApxTOne'
	| PDown _ => ApxTDown' $ newApxTVar ()
	| PAffi _ => ApxTAffi' $ newApxTVar ()
	| PBang _ => ApxTBang' $ newApxTVar ()

(* apxCheckKind : context * kind -> kind *)
fun apxCheckKind (ctx, ki) = case Kind.prj ki of
	  Type => Type'
	| KPi (x, A, K) =>
			let val A' = apxCheckType (ctx, A)
			in KPi' (x, A', apxCheckKind (ctxCondPushINT (x, asyncTypeToApx A', ctx), K)) end

(* apxCheckType : context * asyncType -> asyncType *)
and apxCheckType (ctx, ty) =
	if !traceApx then
		let fun join [] = ""
			  | join [s] = s
			  | join (s::ss) = s^", "^join ss
			val t = join (map (fn (x, A, _) =>
							(x^":"^PrettyPrint.printType (unsafeCast A))) (ctx2list ctx))
			val t = t^"|- "^PrettyPrint.printPreType ty
			val () = apxCount := !apxCount + 1
			val a = Int.toString (!apxCount)
			val () = print ("ApxChecking["^a^"]: "^t^" : Type\n")
			val ty' = apxCheckType' (ctx, ty)
			val () = print ("ApxDone["^a^"]: "^t^" ==> "^PrettyPrint.printType ty'^"\n")
		in ty' end
	else apxCheckType' (ctx, ty)
and apxCheckType' (ctx, ty) = if isUnknown ty then ty else case AsyncType.prj ty of
	  TLPi (p, A, B) =>
			let val A' = apxCheckSyncType (ctx, A)
				fun errmsg () = "stub2"
				val () = apxUnify (ApxTMonad' $ syncTypeToApx A',
						ApxTMonad' $ apxInferPattern p, errmsg)
			in TLPi' (p, A', apxCheckType (tpatBindApx (p, syncTypeToApx A') ctx, B)) end
	| AddProd (A, B) => AddProd' (apxCheckType (ctx, A), apxCheckType (ctx, B))
	| TMonad S => TMonad' (apxCheckSyncType (ctx, S))
	| TAtomic (a, S) =>
		(case Signatur.sigGetTypeAbbrev a of
			  SOME ty =>
				let val _ = apxCheckTypeSpine (ctx, S, ApxType') (* S = TNil *)
				in TAbbrev' (a, ty) end
			| NONE =>
				let val K = kindToApx (Signatur.sigLookupKind a)
					val nImpl = Signatur.getImplLength a
					val S' = foldr TApp' S (List.tabulate (nImpl, fn _ => Parse.blank ()))
				in TAtomic' (a, apxCheckTypeSpine (ctx, S', K)) end)
	| TAbbrev _ => raise Fail "Internal error: TAbbrev cannot occur yet\n"

(* apxCheckTypeSpine : context * typeSpine * apxKind -> typeSpine *)
(* checks that the spine is : ki > Type *)
and apxCheckTypeSpine (ctx, sp, ki) = case (TypeSpine.prj sp, ApxKind.prj ki) of
	  (TNil, ApxType) => TNil'
	| (TNil, ApxKPi _) => raise Fail "Wrong kind; expected Type\n"
	| (TApp _, ApxType) => raise Fail "Wrong kind; cannot apply Type\n"
	| (TApp (N, S), ApxKPi (A, K)) =>
			let val (_, N') = apxCheckObj (ctx, N, A)
			in TApp' (N', apxCheckTypeSpine (ctx, S, K)) end

(* apxCheckSyncType : context * syncType -> syncType *)
and apxCheckSyncType (ctx, ty) = case SyncType.prj ty of
	  LExists (p, A, S) =>
			let val A' = apxCheckSyncType (ctx, A)
				fun errmsg () = "stub2"
				val () = apxUnify (ApxTMonad' $ syncTypeToApx A',
						ApxTMonad' $ apxInferPattern p, errmsg)
			in LExists' (p, A', apxCheckSyncType (tpatBindApx (p, syncTypeToApx A') ctx, S)) end
	| TOne => TOne'
	| TDown A => TDown' (apxCheckType (ctx, A))
	| TAffi A => TAffi' (apxCheckType (ctx, A))
	| TBang A => TBang' (apxCheckType (ctx, A))

(* apxCheckObj : context * obj * apxAsyncType -> context * obj *)
and apxCheckObj (ctx, ob, ty) =
	( if !traceApx then
		( print "ApxChecking: "
		; app (fn (x, A, _) => print (x^":"^PrettyPrint.printType (unsafeCast A)^", "))
			(ctx2list ctx)
		; print ("|- "^PrettyPrint.printPreObj ob^" : "^PrettyPrint.printType (unsafeCast ty)^"\n"))
	  else ()
	; apxCheckObj' (ctx, ob, ty) )
and apxCheckObj' (ctx, ob, A) =
	let val (ctxo, N, A') = apxInferObj (ctx, ob)
		fun errmsg () = "Object " ^ PrettyPrint.printObj N ^ " has type " ^
				PrettyPrint.printType (unsafeCast A') ^ "\n" ^
				"but expected " ^ PrettyPrint.printType (unsafeCast A) ^ "\n"
	in apxUnify (A, A', errmsg); (ctxo, N) end

(* apxInferObj : context * obj -> context * obj * apxAsyncType *)
and apxInferObj (ctx, ob) = case Util.ObjAuxDefs.prj2 ob of
	  Redex (Redex (N, A, S1), _, S2) => apxInferObj (ctx, Redex' (N, A, appendSpine (S1, S2)))
	| Redex (Atomic (H, S1), _, S2) => apxInferObj (ctx, Atomic' (H, appendSpine (S1, S2)))
	| _ => case Obj.prj ob of
	  LLam (p, N) =>
			let val A = apxInferPattern p
				val (ctxo, N', B) = apxInferObj (opatBindApx (p, A) ctx, N)
			in (patUnbind (p, ctxo), LLam' (p, N'), ApxLolli' (A, B)) end
	| AddPair (N1, N2) =>
			let val (ctxo1, N1', A1) = apxInferObj (ctx, N1)
				val (ctxo2, N2', A2) = apxInferObj (ctx, N2)
			in (ctxAddJoin (ctxo1, ctxo2), AddPair' (N1', N2'), ApxAddProd' (A1, A2)) end
	| Monad E => (fn (c, e, s) => (c, Monad' e, ApxTMonad' s)) (apxInferExp (ctx, E))
	| Atomic (H, S) =>
			let val (ctxm, H', nImpl, A) = apxInferHead (ctx, H)
				val S' = foldr LApp' S (List.tabulate (nImpl, fn _ => Bang' $ Parse.blank ()))
				fun atomRedex (INL h, sp) = Atomic' (h, sp)
				  | atomRedex (INR h, sp) = Redex' (h, A, sp)
				fun h2str sp = PrettyPrint.printObj $ atomRedex (H', sp)
				val (ctxo, S'', B) = apxInferSpine (ctxm, S', A, h2str)
			in (ctxo, atomRedex (H', S''), B) end
	| Redex (N, A, S) =>
			let val (ctxm, N') = apxCheckObj (ctx, N, A)
				fun h2str sp = PrettyPrint.printObj $ Redex' (N', A, sp)
				val (ctxo, S', B) = apxInferSpine (ctxm, S, A, h2str)
			in (ctxo, Redex' (N', A, S'), B) end
	| Constraint (N, A) =>
			let val A' = apxCheckType (ctxIntPart ctx, A)
				val apxA' = asyncTypeToApx A'
				val (ctxo, N') = apxCheckObj (ctx, N, apxA')
			in (ctxo, Constraint' (N', A'), apxA') end

(* apxInferHead : context * head -> context * (head, obj) sum * int * apxAsyncType *)
and apxInferHead (ctx, h) = case h of
	  Const c =>
			(case ctxLookupName (ctx, c) of
				  SOME (n, M, A, ctxo) => (ctxo, INL (Var (M, n)), 0, A)
				| NONE =>
					if ucase c then
						(ctx, INL (UCVar c), 0, ImplicitVars.apxUCLookup c)
					else (case Signatur.sigGetObjAbbrev c of
						  SOME (ob, ty) => (ctx, INR ob, 0, asyncTypeToApx ty)
						| NONE => (ctx, INL (Const c), Signatur.getImplLength c,
							asyncTypeToApx (Signatur.sigLookupType c))))
	| Var _ => raise Fail "de Bruijn indices shouldn't occur yet\n"
	| UCVar _ => raise Fail "Upper case variables shouldn't occur yet\n"
	| X as LogicVar {ty, ...} => (ctx, INL X, 0, asyncTypeToApx ty)

(* apxInferSpine : context * spine * apxAsyncType * (spine -> string)
	-> context * spine * apxAsyncType *)
and apxInferSpine (ctx, sp, ty, h2str) = case Spine.prj sp of
	  Nil => (ctx, Nil', ty)
	| LApp (M, S) =>
			let val (ctxm, M', A) = apxInferMonadObj (ctx, M)
				val B = newApxTVar ()
				fun errmsg () = "Object " ^ h2str Nil' ^ " has type " ^
						PrettyPrint.printType (unsafeCast ty) ^ "\n" ^
						"but is applied to " ^ PrettyPrint.printMonadObj M' ^ " of type " ^
						PrettyPrint.printSyncType (unsafeCastS A) ^ "\n"
				val () = apxUnify (ty, ApxLolli' (A, B), errmsg)
				val (ctxo, S', tyo) = apxInferSpine (ctxm, S, B, fn s => h2str $ LApp' (M', s))
			in (ctxo, LApp' (M', S'), tyo) end
	| ProjLeft S =>
			let val A = newApxTVar ()
				val B = newApxTVar ()
				fun errmsg () = "Object " ^ h2str Nil' ^ " has type " ^
						PrettyPrint.printType (unsafeCast ty) ^ "\n" ^
						"but is used as pair\n"
				val () = apxUnify (ty, ApxAddProd' (A, B), errmsg)
				val (ctxo, S', tyo) = apxInferSpine (ctx, S, A, fn s => h2str $ ProjLeft' s)
			in (ctxo, ProjLeft' S', tyo) end
	| ProjRight S =>
			let val A = newApxTVar ()
				val B = newApxTVar ()
				fun errmsg () = "Object " ^ h2str Nil' ^ " has type " ^
						PrettyPrint.printType (unsafeCast ty) ^ "\n" ^
						"but is used as pair\n"
				val () = apxUnify (ty, ApxAddProd' (A, B), errmsg)
				val (ctxo, S', tyo) = apxInferSpine (ctx, S, B, fn s => h2str $ ProjRight' s)
			in (ctxo, ProjRight' S', tyo) end

(* apxInferExp : context * expObj -> context * expObj * apxSyncType *)
and apxInferExp (ctx, ex) =
	let fun letRed (p, S, ob, E) = case Obj.prj ob of
			Atomic hS => Let' (p, hS, E) | _ => LetRedex' (p, S, ob, E)
	in case ExpObj.prj ex of
	  LetRedex (p, sty, N, E) =>
			let fun errmsg () = "stub2"
				val () = apxUnify (ApxTMonad' sty, ApxTMonad' $ apxInferPattern p, errmsg)
				val (ctxm, N') = apxCheckObj (ctx, N, ApxTMonad' sty)
				val (ctxo', E', S) = apxInferExp (opatBindApx (p, sty) ctxm, E)
			in (patUnbind (p, ctxo'), letRed (p, sty, N', E'), S) end
	| Let (p, hS, E) => apxInferExp (ctx, LetRedex' (p, apxInferPattern p, Atomic' hS, E))
	| Mon M => (fn (ctxo, M', S) => (ctxo, Mon' M', S)) (apxInferMonadObj (ctx, M))
	end

(* apxInferMonadObj : context * monadObj -> context * monadObj * apxSyncType *)
and apxInferMonadObj (ctx, mob) = case MonadObj.prj mob of
	  DepPair (M1, M2) =>
			let val (ctxm, M1', S1) = apxInferMonadObj (ctx, M1)
				val (ctxo, M2', S2) = apxInferMonadObj (ctxm, M2)
			in (ctxo, DepPair' (M1', M2'), ApxTTensor' (S1, S2)) end
	| One => (ctx, One', ApxTOne')
	| Down N => (fn (ctxo, N', A) => (ctxo, Down' N', ApxTDown' A)) (apxInferObj (ctx, N))
	| Affi N => (fn (ctxo, N', A) => (ctxJoinAffLin (ctxo, ctx), Affi' N', ApxTAffi' A))
			(apxInferObj (ctxAffPart ctx, N))
	| Bang N => (fn (_, N', A) => (ctx, Bang' N', ApxTBang' A)) (apxInferObj (ctxIntPart ctx, N))
	| MonUndef => raise Fail "Internal error: apxInferMonadObj: MonUndef"


fun apxCheckKindEC ki = apxCheckKind (emptyCtx, ki)
fun apxCheckTypeEC ty = apxCheckType (emptyCtx, ty)
fun apxCheckObjEC (ob, ty) = #2 (apxCheckObj (emptyCtx, ob, ty))
(*
fun apxCheckObjEC (ob, ty) = case (Obj.prj o #3 o apxInferObj) (emptyCtx, Constraint' (ob, ty)) of
		  Constraint obty => obty
		| _ => raise Fail "Internal error: apxCheckObjEC\n"
*)

end
