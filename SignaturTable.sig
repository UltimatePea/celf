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

signature SIGNATUR_TABLE =
sig

datatype lr = L | R
datatype headType = HdMonad | HdAtom of string

val heads : Syntax.asyncType -> (lr list * headType) list

val resetCands : unit -> unit

val getCandMonad : unit -> (string * lr list * Syntax.asyncType) list
val getCandAtomic : string -> (string * lr list * Syntax.asyncType) list

end
