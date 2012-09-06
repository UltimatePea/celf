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

structure OpSemCtx :> OPSEMCTX =
struct

open Binarymap

exception ExnCtx of string

(* Each cell in the context contains its deBruijn index *)
type 'a localvar = int * string * 'a * Context.modality

(* A context is composed of four lists:
 * - linear part (all names ""),
 * - affine part (all names ""),
 * - non-dependent intuitionistic part (all names ""),
 * - dependent intuitionistic part (real names)
 * Internal invariant: each list is ordered by index *)
type 'a localCtx = (int, string * 'a * Context.modality) dict
type 'a context = int * 'a localCtx * 'a localCtx * 'a localCtx

fun updatePos f (k, (x, a, m)) = (f k, (x, a, m))
fun updateValue f (k, (x, a, m)) = (k, (x, f a, m))
fun getPos (k, _) = k
fun getName (_, (x, _, _)) = x

(* mergeLVlist : int -> 'a localvar list * 'a localvar list -> 'a localvar list *)
fun mergeLVlist ([], ys) = ys
  | mergeLVlist (xs, []) = xs
  | mergeLVlist ((k1, (x1, a1, m1)) :: xs, (k2, (x2, a2, m2)) :: ys) =
    ( case Int.compare (k1, k2) of
        LESS => (k1, (x1, a1, m1)) :: mergeLVlist (xs, (k2, (x2, a2, m2)) :: ys)
      | EQUAL => raise Fail "Internal error: invariant broke in mergeLVlist"
      | GREATER => (k2, (x2, a2, m2)) :: mergeLVlist ((k1, (x1, a1, m1)) :: xs, ys)
    )

(* unifyCtx makes one big list merging all parts of the context *)
fun unifyCtx (diff, lvLin, lvAff, lvNd) =
    List.foldl mergeLVlist [] [List.map (updatePos (fn k=>k+diff)) (listItems lvLin),
                               List.map (updatePos (fn k=>k+diff)) (listItems lvAff),
                               List.map (updatePos (fn k=>k+diff)) (listItems lvNd)]

fun linearIndices (diff, lvLin, _, _) =
    let
      fun mkPos (k, _) = k+diff
    in
      List.map mkPos (listItems lvLin)
    end




(* findNonDep : (int * string * 'a * Context.modality -> bool) -> 'a context
                -> (int * string * 'a * Context.modality) option *)
fun findNonDep f (diff, lvLin, lvAff, lvNd) =
    let
      fun myFind [] = NONE
        | myFind ((k, (x, a, m)) :: ctx) =
          if f (k+diff, x, a, m)
          then SOME (k+diff, x, a, m)
          else myFind ctx
    in
      myFind (listItems lvLin @ listItems lvAff @ listItems lvNd)
    end


fun ctx2list (ctx as (diff, _, _, _)) =
    let
      fun trans n [] = []
        | trans n ((h as (k, (x, a, m))) :: t) =
          case Int.compare (n, k) of
            LESS => ("_", NONE, NONE) :: trans (n+1) (h::t)
          | EQUAL => (x, SOME a, SOME m) :: trans (n+1) t
          | GREATER => raise Fail "Internal error: invariant broke in ctx2list"
      fun ppM Context.LIN = "^"
        | ppM Context.AFF = "@"
        | ppM Context.INT = "!"
      fun pp (k, x, a, m) = Int.toString k ^": "^ppM m^", "
    in
      trans 1 (unifyCtx ctx)
    end


fun emptyCtx () =
    let
      val e = mkDict Int.compare
      val _ = numItems e
    in
      (0, e, e, e)
    end

fun ctxIntPart (diff, _, _, lvNd) = (diff, mkDict Int.compare, mkDict Int.compare, lvNd)

fun ctxAffPart (diff, _, lvAff, lvNd) = (diff, mkDict Int.compare, lvAff, lvNd)

(* removeHyp : 'a context * int * Context.modality -> 'a context *)
fun removeHyp ((ctx as (diff, lvLin, lvAff, lvNd)), n, m) =
    ( case m of
        Context.LIN => (diff, #1 (remove (lvLin, n-diff)), lvAff, lvNd)
      | Context.AFF => (diff, lvLin, #1 (remove (lvAff, n-diff)), lvNd)
      | _ => ctx
    ) handle NotFound => raise Fail "Internal error: removeHyp"


(* ctxPush : string * Context.modality * 'a * 'a context -> 'a context *)
fun ctxPush (x, m, a, (ctx as (diff, lvLin, lvAff, lvNd))) =
    case m of
      Context.LIN => (diff+1, insert (lvLin, ~diff, ("", a, m)), lvAff, lvNd)
    | Context.AFF => (diff+1, lvLin, insert (lvAff, ~diff, ("", a, m)), lvNd)
    | Context.INT =>
      ( case x of
          NONE =>  (diff+1, lvLin, lvAff, insert (lvNd, ~diff, ("", a, m)))
        | SOME _ => (diff+1, lvLin, lvAff, lvNd) )

(* remNeg : 'a context -> 'a context
   Removes elements whose #pos is < 1
   Assumes that positions are ordered
 *)
fun remNeg (diff, lvLin, lvAff, lvNd) =
    let
      fun rem [] = []
        | rem (ctx as (k, _, _, _) :: t) = if k+diff < 1 then rem t else ctx
    in
      (diff, removeLower (lvLin, 1-diff), removeLower (lvAff, 1-diff), removeLower (lvNd, 1-diff))
    end

fun nonDepPart (diff, lvLin, lvAff, lvNd) = (diff, listItems lvLin @ listItems lvAff @ listItems lvNd)

(* ctxPushList : (string * Context.modality * 'a) list -> 'a context -> 'a context *)
fun ctxPushList xs ctx = List.foldl (fn ((x, m, a), ctx) => ctxPush (x, m, a, ctx)) ctx xs


(* ctxPopNum : int -> 'a context -> 'a context *)
fun ctxPopNum n ((diff, lvLin, lvAff, lvNd) : 'a context) : 'a context =
    let
      val allLin = numItems lvLin = 0 orelse getPos (min lvLin) + diff >= 1
    in
      if allLin
      then remNeg (diff-n, lvLin, lvAff, lvNd)
      else raise ExnCtx ("Linear variable "^getName (min lvLin)^" doesn't occur\n")
    end

(* ctxPop : 'a context -> 'a context *)
fun ctxPop ctx = ctxPopNum 1 ctx

fun affIntersect ((diff1, lvLin, lvAff1, lvNd), (diff2, lvAff2, _, _)) =
    raise Fail "TODO: affIntersect"
    (* let *)
    (*   fun inter ([], _) = [] *)
    (*     | inter (_, []) = [] *)
    (*     | inter ((k1, x1, a1, m1) :: t1, (k2, x2, a2, m2) :: t2) = *)
    (*       case Int.compare (k1+diff1, k2+diff1) of *)
    (*         LESS => inter (t1, (k2, x2, a2, m2) :: t2) *)
    (*       | EQUAL => (k1, x1, a1, m1) :: inter (t1, t2) *)
    (*       | GREATER => inter ((k1, x1, a1, m1) :: t1, t2) *)
    (* in *)
    (*   if diff1 <> diff2 then raise Fail "affIntersect FIX!" *)
    (*   else *)
    (*     (diff1, lvLin, inter (lvAff1, lvAff2), lvNd) *)
    (* end *)

fun linearDiff ((diff1, lvLin1, lvAff, lvNd),(diff2, lvLin2, _, _)) =
    raise Fail "TODO: linearDiff"
    (* let *)
    (*   fun linDiff ([], _) = [] *)
    (*     | linDiff (_, []) = [] *)
    (*     | linDiff ((k1, x1, a1, m1) :: t1, (k2, x2, a2, m2) :: t2) = *)
    (*       case Int.compare (k1+diff1, k2+diff1) of *)
    (*         LESS => (k1, x1, a1, m1) :: linDiff (t1, (k2, x2, a2, m2) :: t2) *)
    (*       | EQUAL => linDiff (t1, t2) *)
    (*       | GREATER => raise Fail "Internal error: linearDiff" *)
    (* in *)
    (*   if diff1 <> diff2 then raise Fail "linearDiff FIX!" *)
    (*   else (diff1, linDiff (lvLin1, lvLin2), lvAff, lvNd) *)
    (* end *)

fun nolin (_, lvLin, _, _) = numItems lvLin = 0

end