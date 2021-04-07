# Day 3 impressions

## utop

Continuing the trend of multi-file pain, I could not figure out how to get `utop` to load the
modules I'd declared locally. It seemed to want compiled modules, but dune mangled the compiled
module names and stashed them away somewhere weird. I gave up and just pasted in the code. I finally
found `#mod_use` which solved the problem, though it's unclear to me if the semantics are the same
as when building. (I think yes?) It seems another approach has you build a pre-linked utop using
dune, though not clear how that handles changing code on the fly (the way re-using a module shadows
the previous use).

## Refactoring

Is beautiful. Change a function return value, fix up the compiler errors, and the code works. That
was how I easily added the publish time feature to rsspoetry

## js\_of\_caml

I started looking into creating the landing page, but found the documenation very sparse. I was able
to get a basic `index.html` by looking at how [lemaetech/jsoo_todomvc](/lemaetech/jsoo_todomvc) set
up the js executable and loaded the main.js file from index.html. [Dune's
documentation](https://dune.readthedocs.io/en/stable/jsoo.html) for the build setup was actually
quite clear and useful. I really struggled with figuring out how to get started with the actual code
writing, though.

After staring at a few sample projects (thankfully there are several to browse through), it clicked
that I needed both `js_of_ocaml-compiler` for the compiler and `js_of_ocaml` for the various runtime
modules. Installing it was easy, (`opam install js_of_ocaml`), but still I was stuck on `Unbound
module Dom_html`. Reading through the dune docs and staring at the files installed by opam, it
finally clicked that I needed to first `open Js_of_ocaml`.

## ppx

Before diving into the js\_of\_ocaml-ppx, I wanted to understand how to use the JS libraries without
it. (Maybe biased coming from lisp and needing to understand how leaky macros work). The types I got
from Merlin were unfortunately more than I could follow, so I skipped that step and just added the
ppx. A simple install on opam and dune config were all I needed to get set up. Tuareg handles the
custom syntax ok, though the `##` gets highlighted a bit strangely.

## debugging

Despite writing what I consider a fairly trivial amount of JS (set up a simple event listener), my
first attempt did not work. Debugging the way I'm used to (in the browser dev tools) was quite
painful without source maps, so I resorted to console logs and debugger statements. It doesn't help
that a 43 line .ml file compiles into a 30k line .js file, with extremely non-intuitive
transpilation. I still don't have a functioning UI.
