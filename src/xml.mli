(** Attributes to assign to an XML tag. *)
type attributes = (string * string) list

(** An XML tag or text node. *)
type element

(** Create a new tag element. *)
val tag : string -> attributes -> element list -> element

(** Create a new text node. *)
val text : string -> element

(** Create a new cdata node. *)
val cdata : string -> element

(** Serialize a tree to a string. *)
val serialize_element : element -> string

(** Serialize an element into a buffer. *)
val write_element : Buffer.t -> element -> unit
