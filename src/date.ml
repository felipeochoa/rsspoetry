type date = {year : int; month: int; day: int}
type t = date

let (let+) x f =
  match x with
  | None -> None
  | Some t -> f t

let (and+) o1 o2 =
  match (o1, o2) with
    | Some x1, Some x2 -> Some (x1, x2)
    | _ -> None

(* regexp to parse a date as YYYY-MM-DD *)
let date_re =
  let open Re in
  let digitsn n = repn digit n (Some n) |> group in
  Re.compile @@ seq [digitsn 4; char '-'; digitsn 2; char '-'; digitsn 2]

(* Helper function. Returns the number of days in a month. *)
let month_length year month =
  let is_leap y = (y mod 4) = 0 && ((y mod 100) != 0 || (y mod 400) = 0) in
  let month_lengths_ignore_leap = [|0; 31; 28; 31; 30; 31; 30; 31; 31; 30; 31; 30; 31|] in
  if month != 2
  then month_lengths_ignore_leap.(month)
  else if is_leap year then 29
  else 28

let of_string date_s =
  let+ groups = Re.exec_opt date_re date_s in
  let+ year = int_of_string_opt (Re.Group.get groups 1)
  and+ month = int_of_string_opt (Re.Group.get groups 2)
  and+ day = int_of_string_opt (Re.Group.get groups 3)
  in
  if (month < 1 || month > 12) then None
  else if (day < 1 || day > (month_length year month)) then None
  else Some {year; month; day}

let rfc2822 {year; month; day} =
  let pad0 d = (if d < 10 then "0" else "") ^ string_of_int d in
  let month_names = [|"Jan"; "Feb"; "Mar"; "Apr"; "May"; "Jun"; "Jul"; "Aug"; "Sep"; "Oct"; "Nov"; "Dec"|] in
  let day_names = [|"Mon"; "Tue"; "Wed"; "Thu"; "Fri"; "Sat"; "Sun"|] in
  let weekday =
    let offsets = [|0; 3; 2; 5; 0; 3; 5; 1; 4; 6; 2; 4|] in
    let y = if month < 3 then year - 1 else year in
    let num = (y + y/4 - y/100 + y/400 + offsets.(month - 1) + day) mod 7 in
    day_names.(num)
  in
  Printf.sprintf "%s, %s %s %d 00:00:00 GMT" weekday (pad0 day) (month_names.(month)) year

let days_between d1 d2 =
  let julian_day_number {year; month; day} =
    (1461 * (year + 4800 + (month - 14)/12))/4
    + (367 * (month - 2 - 12 * ((month - 14)/12)))/12
    - (3 * ((year + 4900 + (month - 14)/12)/100))/4
    + day
  in
  (julian_day_number d2) - (julian_day_number d1)

let today () =
  let gm = Unix.time () |> Unix.gmtime in
  {year = 1900 + gm.tm_year; month = 1 + gm.tm_mon; day = gm.tm_mday}

let incr_date {year; month; day} =
  if day = month_length year month then
    if month = 12
    then {year = year + 1; month = 1; day = 1}
    else {year; month = month + 1; day = 1}
  else {year; month; day = day + 1}
