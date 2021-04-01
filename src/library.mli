(**
 * Reads a data directory into an map of lists by poet. Expects each data_dir/* to be directories
 * with the poems for each poet. data_dir/*/* should be UTF-8 formatted text files. The poet names
 * should be stores in data_dir/*/name
 *)

type poem =
  { id      : string;
    title   : string;
    content : string;
  }

val load_data : string -> ((string * string list) list, (string * poem list) list) Either.t

val load_author_names : string -> (string * string) list
