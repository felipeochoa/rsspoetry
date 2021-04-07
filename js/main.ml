open Js_of_ocaml

let (let+) = Js.Opt.map
let (let*) = Js.Opt.bind

let js = Js.string
let concat_7 s1 s2 s3 s4 s5 s6 s7 = (s1##concat_4 s2 s3 s4 s5)##concat_3 s5 s6 s7

let main () =
  let+ form = Dom_html.document##querySelector (js "form") in
  let input name =
    let* elem = form##querySelector (js @@ "[name='" ^ name ^ "']") in
    Dom_html.CoerceTo.input elem
  in
  let+ collection = input "collection" in
  let+ date = input "date" in
  let+ time = input "time" in
  let+ output =
    let* elem = Dom_html.document##querySelector (js "#feed-url") in
    Dom_html.CoerceTo.a elem
  in
  let on_input _ _ =
    Js.debugger ();
    output##.href := concat_7
                       (js "/") collection##.value
                       (js "/") date##.value
                       (js "T") time##.value
                       (js "Z/");
    true
  in
  [
    Dom_events.listen collection Dom_events.Typ.change on_input;
    Dom_events.listen date Dom_events.Typ.change on_input;
    Dom_events.listen time Dom_events.Typ.change on_input
  ]

let show_generator () =
  let+ generator = Dom_html.document##querySelector (js "#generator") in
  generator##.style##.display := js "block"

let () =
  ignore @@ show_generator ();
  ignore @@ main ()
