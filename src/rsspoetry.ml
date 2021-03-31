open Cohttp
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

(* Regexp to match a valid feed path /<author>/YYYY-MM-DD/ *)
let feed_re =
  let open Re in
  let digitsn n = repn digit n (Some n) |> group in
  let author = alt [alnum; char '-'] |> rep1 in
  let date = seq [digitsn 4; char '-'; digitsn 2; char '-'; digitsn 2] in
  seq [bos; char '/'; group author; char '/'; group date; opt (char '/'); eos]
  |> compile

(* Parse a feed URI into an author/date pair *)
let get_feed uri_path =
  let+ groups = Re.exec_opt feed_re uri_path in
  let author_s, date_s = (Re.Group.get groups 1, Re.Group.get groups 2) in
  let+ date = Date.of_string date_s
  in Some (author_s, date)


(* Like Array.fold_left, but including an index argument *)
let fold_left_i fn init arr =
  let i = ref (-1) in Array.fold_left (fun acc elt -> i := !i + 1; fn !i acc elt) init arr

type poem = {name : string; text: string; author: string}

type rss_item = {title: string; pub_date: Date.t; creator: string; guid: string; description: string; content: string}

let xml_gen items =
  let buf = Buffer.create 10000 in
  Buffer.add_string buf "<?xml version='1.0' encoding='UTF-8'?>";
  Xml.write_element buf @@
    Xml.tag "rss" ["version", "2.0";
                   "xmlns:content", "http://purl.org/rss/1.0/modules/content/";
                   "xmlns:atom", "http://www.w3.org/2005/Atom";
                   "xmlns:sy", "http://purl.org/rss/1.0/modules/syndication/";
                   "xmlns:media", "http://search.yahoo.com/mrss/";
                   "xmlns:wfw", "http://wellformedweb.org/CommentAPI/";
                   "xmlns:dc", "http://purl.org/dc/elements/1.1/"] [
        Xml.tag "channel" [] @@
          List.append [
            Xml.tag "title" [] [Xml.text "RSS Poetry"];
            Xml.tag "link" [] [Xml.text "https://rsspoetry.com"];
	    Xml.tag "description" [] [Xml.text "Daily poem"];
	    Xml.tag "lastBuildDate" [] [Xml.text (Date.rfc2822 @@ Date.today ())];
	    Xml.tag "language" [] [Xml.text "en-US"];
            Xml.tag "generator" [] [Xml.text "rsspoetry.ml"];
            Xml.tag "sy:updatePeriod" [] [Xml.text "daily"];
	    Xml.tag "sy:updateFrequency" [] [Xml.text "1"];
          ] (
            items
            |> Array.to_list
            |> List.map (fun {title; pub_date; creator; guid; description; content} ->
                   Xml.tag "item" [] [
                       Xml.tag "title" [] [Xml.text title];
                       Xml.tag "pubDate" [] [Xml.text (Date.rfc2822 pub_date)];
                       Xml.tag "dc:creator" [] [Xml.cdata creator];
                       Xml.tag "guid" ["isPermaLink", "false"] [Xml.text guid];
                       Xml.tag "description" [] [Xml.cdata description];
                       Xml.tag "content:encoded" [] [Xml.cdata @@ Printf.sprintf "<pre>%s</pre>" content];
                     ]
                 )
          )
    ];
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

let data = load_data Sys.argv.(1)

let server =
  let body_fn req =
    let+ (author, date) = req |> Request.uri |> Uri.path |> get_feed in
    let+ all_articles = List.assoc_opt author data in
    let num_articles = (1 + Date.days_between date (Date.today ()) |> (max 0) |> (min (Array.length all_articles))) in
    let articles = Array.sub all_articles 0 num_articles in
    let day = ref date in
    let next_day () =
      let ret = !day in
      day := Date.incr_date !day;
      ret
    in
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
    |> Array.mapi (fun i a -> item_of_article a (next_day ()) i )
    |> xml_gen
    |> Option.some
  in
  let callback _conn req _body =
    Printf.printf "%s %s\n%!" (req |> Request.meth |> Code.string_of_method) (req |> Request.uri |> Uri.to_string);
    if (Request.meth req != `GET)
    then Server.respond_not_found ()
    else match body_fn req with
         | None -> Server.respond_not_found ()
         | Some body -> Server.respond_string ~status:`OK ~body ()
  in
  Printf.printf "Starting server on 10101\n%!";
  Server.create ~mode:(`TCP (`Port 10101)) (Server.make ~callback ())

let () = Lwt_main.run server
