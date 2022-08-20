fortsearch
==========

[fortsearch](https://github.com/d-zo/fortsearch) is a shell script to find and highlight modules,
subroutines, functions, and variables from all (Fortran 90+) files in a given directory.
Internally the hard work is done almost exclusively by grep and sed commands.
It was created alongside work at the German Climate Computing Center in Hamburg.


Installation
------------

fortsearch does not have to be installed. To run the script, simply download it and execute it like
```
bash fortsearch.sh
```

If this script proves to be useful, a good place is to store or link it as `fortsearch`
with executable permissions within a `PATH` directory of the current user (sometimes `~/.local/bin/`).
This allows calling it from any terminal simply by
```
fortsearch
```


Usage
-----

Typically fortsearch needs some options for a meaningful run like

 - the path to a directory with Fortran source code files of interest (`fort-search-dir`)
 - What the search should focus on:
    - either variable names (`-var`),
    - function/subroutine names (`-fun`), or
    - module names (`-mod`)

 - What name to search for (`search-term`)
 - Optionally if only its definition should be found (`def`) or the usage of derived values from it (`outer`)

In short, the command is

```
fortsearch [fort-search-dir] {-var|-fun|-mod} <search-term> [def|outer]
```


Shortcomings
------------

Although fortsearch does find all regular uses of variables/functions/subroutines/modules,
it does also return false positives (e.g. when the name is used within a string).
Usually these can easily be spotted and can be ruled out.

fortsearch does not do any macro processing.
So any names generated as a result of a macro operation should not be expected to be found.

Currently there should be no colons (`:`) in the filename or the highlighting will not work correctly.



Contributing
------------

**Bug reports**

If you found a bug, make sure you can reproduce it with the latest version of fortsearch
and not part of the known shortcomings.


License
-------

fortsearch is released under the BSD 3-Clause "Revised" License
(see also [LICENSE](https://github.com/d-zo/fortsearch/blob/master/LICENSE) file).
It is provided without any warranty.
