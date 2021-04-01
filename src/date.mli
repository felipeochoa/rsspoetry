type t

(** Parse a YYYY-MM-DD string into a date *)
val of_string : string -> t option

(** Output a date as a string in RFC 2822 format *)
val rfc2822 : t -> string

(** Output a date as YYYY-MM-DD *)
val to_string : t -> string

(** Calculate number of days between two dates **)
val days_between : t -> t -> int

(** Today, in UTC *)
val today : unit -> t

(** Return the day following the given date **)
val incr_date : t -> t
