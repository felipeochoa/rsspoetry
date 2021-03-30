open Cohttp_lwt_unix

(* Monadic syntax using Option. This is useful for all the parsing bits. *)
let (let+) x f =
  match x with
  | None -> None
  | Some t -> f t

let (and+) o1 o2 =
  match (o1, o2) with
    | Some x1, Some x2 -> Some (x1, x2)
    | _ -> None

(* regexp to parse a date as YYYY-MM-DD *)
let date_raw =
  let open Re in
  let digitsn n = repn digit n (Some n) |> group in
  seq [digitsn 4; char '-'; digitsn 2; char '-'; digitsn 2]
let date_re = Re.compile date_raw

(* Helper function. Returns the number of days in a month. *)
let month_length year month =
  let is_leap y = (y mod 4) = 0 && ((y mod 100) != 0 || (y mod 400) = 0) in
  let month_lengths_ignore_leap = [|0; 31; 28; 31; 30; 31; 30; 31; 31; 30; 31; 30; 31|] in
  if month != 2
  then month_lengths_ignore_leap.(month)
  else if is_leap year then 29
  else 28

type date = {year : int; month: int; day: int}

(* Parse a YYYY-MM-DD string into a date *)
let date_of_string date_s =
  let+ groups = Re.exec_opt date_re date_s in
  let+ year = int_of_string_opt (Re.Group.get groups 1)
  and+ month = int_of_string_opt (Re.Group.get groups 2)
  and+ day = int_of_string_opt (Re.Group.get groups 3)
  in
  if (month < 1 || month > 12) then None
  else if (day < 1 || day > (month_length year month)) then None
  else Some {year; month; day}

(* Output a date as YYYY-MM-DD *)
let print_date {year; month; day} =
  let pad0 d = (if d < 10 then "0" else "") ^ string_of_int d in
  Printf.sprintf "%d-%s-%s" year (pad0 month) (pad0 day)

let isodate {year; month; day} =
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

(* Calculate number of days between two dates *)
let days_between d1 d2 =
  let julian_day_number {year; month; day} =
    (1461 * (year + 4800 + (month - 14)/12))/4
    + (367 * (month - 2 - 12 * ((month - 14)/12)))/12
    - (3 * ((year + 4900 + (month - 14)/12)/100))/4
    + day
  in
  (julian_day_number d2) - (julian_day_number d1)

(* Today, as a `date` *)
let today () =
  let gm = Unix.time () |> Unix.gmtime in
  {year = 1900 + gm.tm_year; month = 1 + gm.tm_mon; day = gm.tm_mday}

(* Return the day following the given date *)
let incr_date date_ref =
  let {year; month; day} = !date_ref in
  date_ref := if day = month_length year month then
                if month = 12
                then {year = year + 1; month = 1; day = 1}
                else {year; month = month + 1; day = 1}
              else {year; month; day = day + 1}

(* Regexp to match a valid feed path /<author>/YYYY-MM-DD/ *)
let feed_re =
  let open Re in
  let author = alt [alnum; char '-'] |> rep1 in
  seq [bos; char '/'; group author; char '/'; group date_raw; opt (char '/'); eos]
  |> compile

(* Parse a feed URI into an author/date pair *)
let get_feed uri_path =
  let+ groups = Re.exec_opt feed_re uri_path in
  let author_s, date_s = (Re.Group.get groups 1, Re.Group.get groups 2) in
  let+ date = date_of_string date_s
  in Some (author_s, date)

(* Like Array.fold_left, but including an index argument *)
let fold_left_i fn init arr =
  let i = ref (-1) in Array.fold_left (fun acc elt -> i := !i + 1; fn !i acc elt) init arr

type poem = {name : string; text: string; author: string}

type rss_item = {title: string; pub_date: date; creator: string; guid: string; description: string; content: string}

let xml_gen items =
  let buf = Buffer.create 10000 in
  Buffer.add_string buf "<?xml version='1.0' encoding='UTF-8'?><rss version='2.0'
  xmlns:content='http://purl.org/rss/1.0/modules/content/'
  xmlns:atom='http://www.w3.org/2005/Atom'
  xmlns:sy='http://purl.org/rss/1.0/modules/syndication/'
  xmlns:media='http://search.yahoo.com/mrss/'
  xmlns:wfw='http://wellformedweb.org/CommentAPI/'
  xmlns:dc='http://purl.org/dc/elements/1.1/'
><channel>
	<title>Quanta Magazine</title>
	<atom:link href='https://api.quantamagazine.org/feed/' rel='self' type='application/rss+xml'></atom:link>
	<link>https://www.quantamagazine.org</link>
	<description>Illuminating science</description>
	<lastBuildDate>Mon, 29 Mar 2021 16:20:25 +0000</lastBuildDate>
	<language>en-US</language>
	<sy:updatePeriod>daily</sy:updatePeriod>
	<sy:updateFrequency>1</sy:updateFrequency>
	<generator>https://wordpress.org/?v=4.7.3</generator>
	<atom:link rel='hub' href='https://pubsubhubbub.appspot.com/' />
	<managingEditor>quanta@simonsfoundation.org (Quanta Magazine)</managingEditor>
	<copyright>Quanta Magazine</copyright>
	<image>
		<title>Quanta Magazine</title>
		<url>https://d2r55xnwy6nx47.cloudfront.net/uploads/2017/12/quanta_podcast_logo-1400.png</url>
		<link>https://www.quantamagazine.org</link>
	</image>";
  items |> Array.iter (fun {title; pub_date; creator; guid; description; content} ->
             Printf.bprintf buf "<item><title>%s</title><pubDate>%s</pubDate>
<dc:creator><![CDATA[%s]]></dc:creator>
<guid isPermaLink='false'>%s</guid>
<description><![CDATA[%s]]></description>
<content:encoded><![CDATA[<pre>%s</pre>]]></content:encoded>
</item>" title (isodate pub_date) creator guid description content
             );
  Buffer.add_string buf "</channel></rss>";
  Buffer.contents buf

(* Reads a data directory into an alist by poet. Expects each data_dir/* to be directories
 * with the poems for each poet. data_dir/*/* should be UTF-8 formatted text files
 *)
let load_data data_dir =
  let read_file name =
    let chan = open_in_bin name in
    let size = in_channel_length chan in
    let buf = Buffer.create size in
    Buffer.add_channel buf chan size;
    close_in chan;
    Buffer.contents buf
  in
  let read_files author_dir =
    let base_dir = Filename.concat data_dir author_dir in
    base_dir
    |> Sys.readdir
    |> Array.map (fun name -> {
                      name = Filename.chop_extension name;
                      text = read_file (Filename.concat base_dir name);
                      author = author_dir;
         })
  in
  Sys.readdir data_dir
  |> Array.map (fun author -> (author, read_files author))
  |> Array.to_list

let data = load_data "./data"

let server =
  let body_fn req =
    let+ (author, date) = req |> Request.uri |> Uri.path |> get_feed in
    let+ all_articles = List.assoc_opt author data in
    let num_articles = (1 + days_between date (today ()) |> (max 0) |> (min (Array.length all_articles))) in
    let articles = Array.sub all_articles 0 num_articles in
    let day = ref date in
    (* let header = Printf.sprintf "Author: %s\nDate: %s\nPoems: %d" author (print_date date) num_articles in
     * let article_size = Array.fold_left (fun acc elt -> acc + (String.length elt.text)) 0 articles in
     * let body = Buffer.create (String.length header + article_size) in
     * Buffer.add_string body header;
     * articles
     * |> Array.iter (fun article ->
     *        Printf.bprintf body "\n\n## %s (%s)\n\n%s\n" article.name (print_date !day) article.text;
     *        day := incr_date !day);
     * Some (Buffer.contents body) *)
    let item_of_article article pub_date i = {
        title = article.name;
        pub_date;
        creator = article.author;
        guid = "";
        description = "Poem " ^ string_of_int i;
        content = article.text;
      }
    in
    articles
    |> Array.mapi (fun i a -> let ret = item_of_article a !day i in incr_date day; ret)
    |> xml_gen
    |> Option.some
  in
  let callback _conn req _body =
    if (Request.meth req != `GET)
    then Server.respond_not_found ()
    else match body_fn req with
         | None -> Server.respond_not_found ()
         | Some body -> Server.respond_string ~status:`OK ~body ()
  in
  Server.create ~mode:(`TCP (`Port 10101)) (Server.make ~callback ())

let () = Lwt_main.run server
