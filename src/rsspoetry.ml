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

(* Return a list of just the first i elements. If not enough elements, return the whole list. *)
let take i list =
  let rec take_tail_rec i list acc =
    if i = 0 then List.rev acc
    else match list with
         | [] -> List.rev acc
         | h :: t -> take_tail_rec (i - 1) t (h :: acc)
  in
  take_tail_rec i list []

type rss_item = {title: string; pub_date: Date.t; creator: string; guid: string; description: string; content: string}

let xml_gen feed_path feed_title items =
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
            Xml.tag "title" [] [Xml.text @@ "Read in RSS | " ^ feed_title];
            Xml.tag "atom:link" ["href", "https://readinrss.com" ^ feed_path;
                                 "rel", "self";
                                 "type", "application/rss+xml"] [];
            Xml.tag "link" [] [Xml.text @@ "https://readinrss.com" ^ feed_path];
	    Xml.tag "description" [] [Xml.text "Daily poem"];
	    Xml.tag "lastBuildDate" [] [Xml.text (Date.rfc2822 @@ Date.today ())];
	    Xml.tag "language" [] [Xml.text "en-US"];
            Xml.tag "generator" [] [Xml.text "rsspoetry.ml"];
            Xml.tag "sy:updatePeriod" [] [Xml.text "daily"];
	    Xml.tag "sy:updateFrequency" [] [Xml.text "1"];
          ] (
            items
            |> List.map (fun {title; pub_date; creator; guid; description; content} ->
                   Xml.tag "item" [] [
                       Xml.tag "title" [] [Xml.text title];
                       Xml.tag "pubDate" [] [Xml.text (Date.rfc2822 pub_date)];
                       Xml.tag "dc:creator" [] [Xml.cdata creator];
                       Xml.tag "guid" ["isPermaLink", "false"] [Xml.text guid];
                       Xml.tag "description" [] [Xml.cdata description];
                       Xml.tag "content:encoded" [] [Xml.cdata content];
                     ]
                 )
          )
    ];
  Buffer.contents buf

let data =
  match Library.load_data Sys.argv.(1) with
    | Either.Right d -> d
    | Either.Left errs ->
       failwith @@ String.concat "; "
                     (List.map (fun (_, author_errs) -> String.concat "; " author_errs) errs)

let author_names = Library.load_author_names Sys.argv.(1)

let server =
  let body_fn req =
    let path = req |> Request.uri |> Uri.path in
    let+ (author_id, date) = get_feed path in
    let+ all_articles = List.assoc_opt author_id data in
    let author = (List.assoc author_id author_names) in
    let num_articles = Date.days_between date (Date.today ()) |> (max 0) |> (+) 1 in
    let articles = take num_articles all_articles in
    let day = ref date in
    let next_day () =
      let ret = !day in
      day := Date.incr_date !day;
      ret
    in
    let item_of_article author pub_date (article : Library.poem) = {
        title = article.title;
        pub_date;
        creator = author;
        guid = article.id;
        description = "“" ^ article.title ^ "” by " ^ author;
        content = article.content;
      }
    in
    articles
    |> List.map (fun a -> item_of_article author (next_day ()) a)
    |> xml_gen path (author ^ " | " ^ Date.to_string date)
    |> Option.some
  in
  let callback _conn req _body =
    let start = Unix.gettimeofday () in
    let res = if (Request.meth req != `GET) then None else body_fn req in
    Printf.printf "%s %s %d (%.2fms) \"%s\"\n%!"
      (req |> Request.meth |> Code.string_of_method)
      (req |> Request.uri |> Uri.path_and_query)
      (if Option.is_none res then 404 else 200)
      (let d = (Unix.gettimeofday ()) -. start in
       (if d < 0. then d +. (24. *. 60. *. 60.) else d) *. 1000.)
      (req |> Request.headers |> Fun.flip Header.get "User-Agent" |> Option.value ~default:"");
      match res with
        | None -> Server.respond_not_found ()
        | Some body -> Server.respond_string ~status:`OK ~body ()

  in
  Printf.printf "Starting server on 10101\n%!";
  Server.create ~mode:(`TCP (`Port 10101)) (Server.make ~callback ())

let () = Lwt_main.run server
