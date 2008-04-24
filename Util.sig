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

signature UTIL =
sig

structure ObjAuxDefs : AUX_DEFS where type 'a T.F = 'a Syntax.objF and type T.t = Syntax.obj

structure KindRec : REC2 where type ('a, 't) T.F = ('a, 't) Syntax.kindFF
		and type T.t = Syntax.kind and type T.a = Syntax.asyncType
structure AsyncTypeRec : REC3 where type ('a, 'b, 't) T.F = ('a, 'b, 't) Syntax.asyncTypeFF
		and type T.t = Syntax.asyncType and type T.a = Syntax.typeSpine
		and type T.b = Syntax.syncType
structure TypeSpineRec : REC2 where type ('a, 't) T.F = ('a, 't) Syntax.typeSpineFF
		and type T.t = Syntax.typeSpine and type T.a = Syntax.obj
structure SyncTypeRec : REC2 where type ('a, 't) T.F = ('a, 't) Syntax.syncTypeFF
		and type T.t = Syntax.syncType and type T.a = Syntax.asyncType
structure ObjRec : REC4 where type ('a, 'b, 'c, 't) T.F = ('a, 'b, 'c, 't) Syntax.objFF
		and type T.t = Syntax.obj and type T.a = Syntax.asyncType
		and type T.b = Syntax.spine and type T.c = Syntax.expObj
structure SpineRec : REC2 where type ('a, 't) T.F = ('a, 't) Syntax.spineFF
		and type T.t = Syntax.spine and type T.a = Syntax.obj
structure ExpObjRec : REC4 where type ('a, 'b, 'c, 't) T.F = ('a, 'b, 'c, 't) Syntax.expObjFF
		and type T.t = Syntax.expObj and type T.a = Syntax.obj
		and type T.b = Syntax.monadObj and type T.c = Syntax.pattern
structure MonadObjRec : REC2 where type ('a, 't) T.F = ('a, 't) Syntax.monadObjFF
		and type T.t = Syntax.monadObj and type T.a = Syntax.obj
structure PatternRec : REC2 where type ('a, 't) T.F = ('a, 't) Syntax.patternFF
		and type T.t = Syntax.pattern and type T.a = Syntax.asyncType

val map1 : ('a -> 'c) -> 'a * 'b -> 'c * 'b
val map2 : ('b -> 'd) -> 'a * 'b -> 'a * 'd
val map12 : ('a -> 'c) -> ('b -> 'd) -> 'a * 'b -> 'c * 'd

val linApp : Syntax.obj * Syntax.obj -> Syntax.obj
val app : Syntax.obj * Syntax.obj -> Syntax.obj
val projLeft : Syntax.obj -> Syntax.obj
val projRight : Syntax.obj -> Syntax.obj
val blank : unit -> Syntax.obj
val headToObj : Syntax.head -> Syntax.obj

val linLamConstr : string * Syntax.asyncType * Syntax.obj -> Syntax.obj
val lamConstr : string * Syntax.asyncType * Syntax.obj -> Syntax.obj

val typePrjAbbrev : Syntax.asyncType -> Syntax.asyncType Syntax.asyncTypeF
val nfTypePrjAbbrev : Syntax.nfAsyncType -> Syntax.nfAsyncType Syntax.nfAsyncTypeF

val apxTypePrjAbbrev : Syntax.apxAsyncType -> Syntax.apxAsyncType Syntax.apxAsyncTypeF

val isNil : Syntax.spine -> bool

val objAppKind : ((unit, unit, unit, unit) Syntax.objFF -> unit) -> Syntax.kind -> unit
val objAppType : ((unit, unit, unit, unit) Syntax.objFF -> unit) -> Syntax.asyncType -> unit
val objAppObj  : ((unit, unit, unit, unit) Syntax.objFF -> unit) -> Syntax.obj -> unit

val objMapKind : (Syntax.obj -> Syntax.obj Syntax.objF) -> Syntax.kind -> Syntax.kind
val objMapType : (Syntax.obj -> Syntax.obj Syntax.objF) -> Syntax.asyncType -> Syntax.asyncType
val objMapObj : (Syntax.obj -> Syntax.obj Syntax.objF) -> Syntax.obj -> Syntax.obj

(* boolean flag indicates a strong rigid context *)
val objSRigMapKind : (bool -> Syntax.obj -> Syntax.obj Syntax.objF) -> bool -> Syntax.kind -> Syntax.kind
val objSRigMapType : (bool -> Syntax.obj -> Syntax.obj Syntax.objF) -> bool -> Syntax.asyncType -> Syntax.asyncType
val objSRigMapObj : (bool -> Syntax.obj -> Syntax.obj Syntax.objF) -> bool -> Syntax.obj -> Syntax.obj

val forceNormalizeKind : Syntax.kind -> Syntax.kind
val forceNormalizeType : Syntax.asyncType -> Syntax.asyncType
val forceNormalizeObj : Syntax.obj -> Syntax.obj

val whnfLetSpine : Syntax.expObj -> Syntax.expObj

val removeApxKind : Syntax.kind -> Syntax.kind
val removeApxType : Syntax.asyncType -> Syntax.asyncType
val removeApxSyncType : Syntax.syncType -> Syntax.syncType
val removeApxObj : Syntax.obj -> Syntax.obj
val asyncTypeFromApx : Syntax.apxAsyncType -> Syntax.asyncType
val syncTypeFromApx : Syntax.apxSyncType -> Syntax.syncType

end
