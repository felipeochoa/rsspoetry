
let (let+) x f =
  match x with
  | None -> None
  | Some t -> f t

(** Read a file in its entirety into a string. *)
let read_file_exn name =
  let chan = open_in_bin name in
  let size = in_channel_length chan in
  let buf = Buffer.create size in
  Buffer.add_channel buf chan size;
  close_in chan;
  Buffer.contents buf

type poem =
  { id      : string;
    title   : string;
    content : string;
  }

let split_string text separator =
  let+ groups = Re.exec_opt (Re.compile @@ Re.str separator) text in
  let start = Re.Group.start groups 0
    and stop = Re.Group.stop groups 0 in
  Some (String.sub text 0 start, String.sub text stop (String.length text - stop))

let poem_of_string id raw_content =
  match split_string raw_content "\n---\n" with
    | None -> Either.Left ("Could not parse " ^ id)
    | Some (title, content) -> Either.Right {id; title; content}

let all_right values =
  let open Either in
  let folder value res =
    match value, res with
      | Left v, Left errs -> left @@ v :: errs
      | Right v, Right vals -> right @@ v :: vals
      | Right _, Left _ -> res
      | Left e, Right _ -> left [e]
  in
  match Array.fold_right folder values (Right []) with
  | Left errs -> Left errs
  | Right vs -> Right vs

let filter fn arr =
  let new_arr = Array.map (fun x -> if fn x then Some x else None) arr in
  let count_some t = function
    | Some _ -> t + 1
    | None -> t
  in
  let new_len = Array.fold_left (count_some) 0 new_arr in
  let ret = Array.sub arr 0 new_len in
  let i = ref 0 in
  Array.iter
    (function
     | Some x -> Array.set ret !i x; i := !i + 1
     | None -> ())
    new_arr;
  ret

let load_author data_dir author_id =
  let base_dir = Filename.concat data_dir author_id in
  base_dir
  |> Sys.readdir
  |> filter ((<>) "name")
  |> Array.map (fun name -> read_file_exn (Filename.concat base_dir name)
                            |> poem_of_string @@ author_id ^ "/" ^ name)
  |> all_right

let load_data data_dir =
  data_dir
  |> Sys.readdir
  |> Array.map (fun author_id -> match load_author data_dir author_id with
                                 | Either.Left errs -> Either.Left (author_id, errs)
                                 | Either.Right vals -> Either.Right (author_id, vals))
  |> all_right

let load_author_names data_dir =
  let get_name author_id =
    read_file_exn ("name" |> Filename.concat author_id |> Filename.concat data_dir)
  in
  data_dir
  |> Sys.readdir
  |> Array.map (fun author_id -> (author_id, get_name author_id))
  |> Array.to_list

(* Filename.chop_extension *)
