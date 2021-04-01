# Day 2 impressions

## Multi-file project

I could not manage to get Merlin to understand that I had and Xml module in a file adjacent to the
main rsspoetry executable, no matter what I tried putting in `.merlin`. (Dune built the executable
just file with no additional config). I tried moving all source files into a new `src` directory,
rebuilding the project, and still no luck. (I initially didn't realize I had to move the dune file
into `src` as well, but eventually figured that out)

Finally thanks to
[Reddit](https://www.reddit.com/r/ocaml/comments/mh9uix/help_configuring_merlin_in_multifile_project/?)
I was able to find [this
question](https://discuss.ocaml.org/t/dune-no-longer-generating-merlin-files/7292) which pointed to
the answer: just delete the `.merlin` file and let dune + merlin communicate directly. Filed a
[PR](https://github.com/ocaml/merlin/pull/1296) to clarify this for future newbies.

## Deployment

Started thinking through deployment. Installing opam + dune was a bit painful on the server, but it
worked. The docker images for opam are all huge (500MB), so not sure about following that
approach. Might be better to statically link locally (with musl?) and put a single binary on the
server.

## Stdlib

The shortcomings of the Ocaml standard library are becoming quite apparent. The lack of
`Array.filter` resulted in some painful and mindless, and probably inefficient code. Missing
`List.take` already caused one silly bug
