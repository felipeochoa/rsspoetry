type attributes = (string * string) list

type tag =
  { name     : string;
    attrs    : attributes;
    children : element list;
  }
and element =
  | Text of string
  | Cdata of string
  | Node of tag

let replacements = [
    '<', "&lt;";
    '>', "&gt;";
    '"', "&quot;";
    '\'', "&apos;";
    '&', "&amp;";
  ]

let escaping_re =
  let fst_char x = Re.char @@ fst x in
  Re.compile @@ Re.alt @@ List.map fst_char replacements

let escape_string =
  let f group = List.assoc (String.get (Re.Group.get group 0) 0) replacements in
  Re.replace escaping_re ~f

let maybe_space str = if String.length str > 0 then " " ^ str else str

let serialize_attributes attrs =
  attrs
  |> List.map (fun (k, v) -> k ^ "=\"" ^ (escape_string v) ^ "\"")
  |> String.concat " "

let rec serialize_element = function
    | Text t -> escape_string t
    | Cdata t ->  "<![CDATA[" ^ t ^ "]]>"
    | Node n -> serialize_tag n
and serialize_tag tag =
  let attrs = maybe_space @@ serialize_attributes tag.attrs in
  let children =
    tag.children
    |> List.map serialize_element
    |> String.concat ""
  in
  if String.length children = 0
  then Printf.sprintf "<%s%s/>" tag.name attrs
  else Printf.sprintf "<%s%s>%s</%s>" tag.name attrs children tag.name

let write_attributes buf =
  List.iter (fun (k, v) -> Printf.bprintf buf " %s=\"%s\"" k (escape_string v))

let rec write_element buf = function
    | Text t -> Buffer.add_string buf @@ escape_string t
    | Cdata t -> Buffer.add_string buf "<![CDATA[";
                 Buffer.add_string buf t;
                 Buffer.add_string buf "]]>"
    | Node n -> write_tag buf n
and write_tag buf tag =
  Buffer.add_char buf '<';
  Buffer.add_string buf tag.name;
  write_attributes buf tag.attrs;
  match tag.children with
    | [] -> Buffer.add_string buf "/>"
    | _ -> Buffer.add_char buf '>';
           List.iter (write_element buf) tag.children;
           Printf.bprintf buf "</%s>" tag.name

let tag name attrs children = Node {name; attrs; children}
let text contents = Text contents
let cdata contents = Cdata contents
