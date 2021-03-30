# Initial impressions on Ocaml

This is a quick post regarding my experience starting off with Ocaml for a real (though small)
project. It's based on ~1 day of work.

## My background

My day job is in Typescript (node + React) and Python (Django). I've written a bunch of lisp (mostly
Emacs, but also Common Lisp). I read most of Real World Ocaml a few months ago, though didn't really
do any of the coding alongside. I've read lots of CS papers and know what a Monad is. I use WSL v1.

## Installation

Getting things up and running was quite straightforward. The Ubuntu ppa didn't work for me, so I had
to download a prebuilt opam binary and then compile Ocaml from scratch. I had to disable bubble-wrap
to work on WSL, but otherwise it just worked.

The concept of a `switch` I don't fully grok yet, but thinking of it like a python virtualenv got me
off the ground and hasn't run me into issues yet.

## Editor setup

I use Emacs, and the last time I picked up a new language (JS) I ended up having to write my own
mode ([rjsx](/felipeochoa/rjsx)). Thankfully, installing Merlin and Tuareg was a piece of cake, and
with a few tweaks to my init file I had error checking, syntax highlighting, jump to definition,
auto-complete (via company), and tool-tips (via merlin-eldoc). I even had occurrence highlighting and nav,
which is the #1 IDE feature I use.

The only tricky points I ran into were:
- Deciding between caml and tuareg modes -- I guessed tuareg and haven't regretted the decision.
- Knowing to add .merlin file in addition to the dune file. In JS-land, everything pulls from
  package.json, so having 2 files with the same info was a bit strange.
- Getting utop working required installing via opam and also via the Emacs package manager. As I
  read the instructions now it's painfully obvious I had to do that, but for some reason I thought
  just installing via Emacs would do it for me. elpy and tide are more helpful here: elpy tells you
  "I'm missing these dependencies; click here to install" and tide just bundles its tsserver dependency.
  It's a shame utop-mode doesn't inherit from comint since I had to redo some customization, and I
  haven't figured out how to `send-region`

All in all, extremely positive experience

## Actually doing work

The way I write code is to start with a minimally working example and progressively add in
complexity where needed by means of many small refactorings. Strong typing + H-M inference is great
for this (though Typescripts type system typically works well too) since it gives me a lot of
confidence that all of my incremental refactors are correct. I find the Ocaml syntax super nice, and
am a super big fan of the monadic let operators. I found it very straightforward to copy in examples
from the internet and modify accordingly. The only piece of syntax that tripped me up for a bit was
the `|>`, but even that I figured out (and loved).

I found there were enough blogs/Stackoverflow posts for me to get through the initial blocking
points (e.g., how do a regex match), which is sometimes a fear with niche languages.

## Libraries

On the topic of niche languages, I do have to say my initial impression of the various libraries is
not great. My biggest gripe is around documentation, since it seems like very few libraries bother
documenting their usage, relying mostly or entirely on auto-generated docs which just have the
function names and signatures. While that can be helpful to understand what a function does, it is
far less useful when trying to figure out how to get something done. As an example, I had a hard
time finding the `Re.Group.get` function, since I expected to be dealing with some sort of match
object, and I expected it to return `option string`. Having some prose beyond the signature gives
more targets for searches to bear fruit. Sample usages would be nice, but even a one-line
description of functions, as [advocated by
Ocamlverse](https://ocamlverse.github.io/content/documentation_guidelines.html), would go a long way.

In terms of library discovery, [Ocamlverse](https://ocamlverse.github.io/) worked great, as did
DuckDuckGo. There aren't zillions of libraries for everything like in Node, but somehow there are
still competing implementations that can cause decision paralysis when you don't know what to
do. Probably the biggest one is the standard library, which I think drives the Lwt vs Async split. I
chose to stick with the default stdlib and use Lwt, and despite a few awkward bits, I don't really
regret the decision.

After a day, I do understand why Jane Street decided to create a new standard library
though. Compared to Python, Ocaml does not have much in the way of batteries included (e.g., you
have to pick and install a 3rd party lib for regexes), and there seem to be a lot of exceptions
throughout the stdlib. I wound up rolling my own date functions since the "blessed" library
[Calendar](https://github.com/ocaml-community/calendar) since I know
just how tricky dates, times, time zones, Julian vs. Gregorian, etc. can be and the documentation
made it hard for me to assess how `Calendar` handled all these things. (Though it was obvious the
author understood these things perfectly)

## Other dev things

I haven't looked into test frameworks, logging, or deployment. I read a bit about multi-file
projects, so punted on breaking this up into modules to save on some yak shaving for now. I'm using
the (I think) low-level `cohttp` library to avoid having to learn and debug a large framework. I can
see how I could build a more robust service on top of it.

## Bottom line

If I were using this for work, I'd want to dig into the standard library/batteries more to
understand if some of these pain points go away. It is clearly an amazing language for actually
writing code, but it seems like you pay for that with increased difficulty when writing glue
code. Having a cohesive and comprehensive standard library would go a long way to resolving that, so
I'm hopeful that either Jane Street/Containers/Batteries solve this problem

## Appendix: Miscellaneous things that tripped me up

None of these were particularly long (this all happened in the span of 1 day), but in case anyone
else stumbles on these

- You can create regexes using the standard Perl/JS/Python/sed/etc. syntax using `Re.Posix.compile_pat`
- The pipeline operator `|>` is similar to the threading macro in various lisps. (E.g., `->>` from
  dash.el) It takes the LHS and pipes it into the RHS. so `3 |> (+) 4` results in 7. Keywords:
  pipe/vertical bar/vertical/line/U+007C greater-than/gt/U+0063/right angle bracket
- If you're building up a large string, use `Buffer` to avoid paying the quadratic cost of string
  concatenation
- Check for functions ending in `_opt` to avoid some exceptions
- You don't need to import modules before using them, the way you would in Python `import sys` or JS
  `import fs from 'fs'`. In Ocaml you just do `Sys.argv` and it works. `open` is akin to `import *`
  in Python and doesn't have an analogue in JS
- Don't reuse record fieldnames in the same module or you might need to add type annotations to help
  the compiler with strange inferences. Or read the [Real World Ocaml
  chapter](https://dev.realworldocaml.org/records.html) and do it right
