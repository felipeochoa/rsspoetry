type t = float

let (let+) x f =
  match x with
  | None -> None
  | Some t -> f t

let (and+) o1 o2 =
  match (o1, o2) with
    | Some x1, Some x2 -> Some (x1, x2)
    | _ -> None

let time hours minutes seconds subseconds =
  float_of_int ((hours * 60 + minutes) * 60 + seconds)
  +. subseconds

let time_of_epoch unix =
  let gm = Unix.gmtime unix in
  time gm.tm_hour gm.tm_min gm.tm_sec (fst @@ Float.modf unix)

let now () = Unix.time () |> time_of_epoch

let time_re =
  let open Re in
  let digitsn n = repn digit n (Some n) |> group in
  Re.compile @@ seq [digitsn 2; char ':'; digitsn 2; char ':'; digitsn 2; opt @@ char 'Z']

let of_string time_s =
  let+ groups = Re.exec_opt time_re time_s in
  let+ hours = int_of_string_opt (Re.Group.get groups 1)
  and+ minutes = int_of_string_opt (Re.Group.get groups 2)
  and+ seconds = int_of_string_opt (Re.Group.get groups 3)
  in
  if (hours < 0 || hours > 23) then None
  else if (minutes < 0 || minutes >= 60) then None
  else if (seconds < 0 || seconds >= 61) then None
  else Some (time hours minutes seconds 0.0)
