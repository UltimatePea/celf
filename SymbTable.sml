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

structure SymbTable :> SYMBTABLE =
struct

type 'a Table = (string, 'a) Binarymap.dict

val empty = fn () => Binarymap.mkDict String.compare
val peek = Binarymap.peek
val insert = Binarymap.insert
(*fun equal (t1,t2) = (Binarymap.listItems t1) = (Binarymap.listItems t2)*)
val toList = Binarymap.listItems
val numItems = Binarymap.numItems
fun delete tk = #1 (Binarymap.remove tk)
val mapTable = Binarymap.transform
fun appTable f t = Binarymap.app (f o #2) t

end
