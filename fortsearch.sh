#!/bin/bash

# Copyright (c) 2022 Dominik Zobel.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# Either ignore matches in comments (1) or not (0)
ignore_comments=1

# A root directory provided here is used as a fallback if no directory
# is given when this script is called
FORT_BASE_ROOT="/path/to/Fortran/sources"


function Usage() {
   echo "Usage: $0 [fort-search-dir] {-var|-fun|-mod} <search-term> [def|outer]"
   echo "   prints lines with occurences of <search-term> in [fort-search-dir]"
   echo "   (typically including Fortran source files). The output depends on"
   echo "   whether <search-term> is a variable (-var), a function/subroutine/"
   echo "   interface (-fun) or module (-mod). A shell variable named FORT_ROOT"
   echo "   can be used Instead of specifying [fort-search-dir]. If only the"
   echo "   definition/creation should be found, pass \"def\" as last argument."
   echo "   To include cases where derived types within are used  (<var>%...),"
   echo "   pass \"outer\""
   echo ""
   echo "   Output for -var has the following flags"
   echo "    C   Creation/initialisation of variable"
   echo "    M   Memory allocation of variable"
   echo "    =   Assignment to variable"
   echo "    .   Other occurences of variable"
   echo ""
   echo "   Output for -fun/-mod has the following flags"
   echo "    C   Creation/initialisation of function/subroutine/interface"
   echo "    E   End of definition"
   echo "    .   Other occurences/calls of function/subroutine/interface"
   exit 1
}

DEF_ONLY=0
WITH_OUTER=0

case $# in
   4) if [ "$4" == "def" ]; then
         DEF_ONLY=1
      elif [ "$4" == "outer" ]; then
         WITH_OUTER=1
      else
         Usage
      fi
      FORT_ROOT="$1"
      SEARCH_TYPE="$2"
      SEARCH_VAR="$3";;
   3) if [ "$3" == "def" ]; then
         DEF_ONLY=1
         SEARCH_TYPE="$1"
         SEARCH_VAR="$2"
      elif [ "$3" == "outer" ]; then
         WITH_OUTER=1
         SEARCH_TYPE="$1"
         SEARCH_VAR="$2"
      else
         FORT_ROOT="$1"
         SEARCH_TYPE="$2"
         SEARCH_VAR="$3"
      fi;;
   2) SEARCH_TYPE="$1"
      SEARCH_VAR="$2";;
   *) Usage;;
esac

if [ "${SEARCH_TYPE}" != "-var" ] && [ "${SEARCH_TYPE}" != "-fun" ] && [ "${SEARCH_TYPE}" != "-mod" ]; then
   Usage;
fi

if [ -z "${FORT_ROOT}" ]; then
   echo "FORT_ROOT unset. Using ${FORT_BASE_ROOT}"
   FORT_ROOT="${FORT_BASE_ROOT}"
else
   echo "Using FORT_ROOT=${FORT_ROOT}"
fi

if [ ! -d "${FORT_ROOT}" ]; then
   echo "FORT_ROOT not found: ${FORT_ROOT}"
   exit 1
fi

COLMARK=\\x1b[33m
COLFILE=\\x1b[32m
COLLINE=\\x1b[35m
COLVAR=\\x1b[31m
COLRESET=\\x1b[0m

# Highlight typemark, file and line number as well as variable in the middle of a code line and at the end
highlightinitial='s!^\(.\{2\}\)'${FORT_ROOT}'/!\1!;'\
's!^\(.\):\([^:]\+\):\([0-9]\+\):!'${COLMARK}'\1'${COLRESET}':'${COLFILE}'\2'${COLRESET}':'${COLLINE}'\3'${COLRESET}':!;'

highlightname='s!\([^A-Za-z0-9_]\+\)\('${SEARCH_VAR}'\)\([^A-Za-z0-9_]\+\)!\1'${COLVAR}'\2'${COLRESET}'\3!gi;'\
's!\([^A-Za-z0-9_]\+\)\('${SEARCH_VAR}'\)$!\1'${COLVAR}'\2'${COLRESET}'!gi'

SEARCH_START_COND='(^|[^A-Za-z0-9_])'
if [ ${WITH_OUTER} -eq 1 ]; then
   SEARCH_END_COND='([^A-Za-z0-9_]|$)'
else
   SEARCH_END_COND='([^A-Za-z0-9_%]|$)'
fi

while IFS= read line; do
   templine=$(echo "${line}" | sed -e 's/[^:]*:[0-9]\+:\(.*\)/\1/')
   # It should not matter, that "!" in strings are also regarded as comments. Otherwise adjust the following lines or use ignore_comments=0
   if [ 1 -eq ${ignore_comments} ]; then
      # Ignore full comment lines
      if [ "x$(echo "${templine}" | egrep -i '^[ ]*!')" != "x" ]; then
         continue
      fi
      # Also ignore all lines with comments where ${SEARCH_VAR} is not found before the comment character
      if [ "x$(echo "${templine}" | sed -e 's/^\([^!]*\).*/\1/g' | egrep -i ${SEARCH_START_COND}${SEARCH_VAR}${SEARCH_END_COND})" == "x" ]; then
         continue
      fi
   fi
   #
   if [ "${SEARCH_TYPE}" == "-var" ]; then
      # NOTE: Definitions with custom types are not recognized as "C" but "."
      if [ "x$(echo "${templine}" | egrep -i '(integer|real|logical|character|double|type).*[, :]+'${SEARCH_VAR}${SEARCH_END_COND})" != "x" ]; then
         typemark='C'
      elif [ "x$(echo "${templine}" | egrep -i 'allocate[ ]*\((.*%|)'${SEARCH_VAR}'[ ]*[()]+')" != "x" ]; then
         typemark='M'
      elif [ "x$(echo "${templine}" | egrep -i '(^[ ]*|.*%)'${SEARCH_VAR}'[ ]*(\([^)]*\)[ ]*|)=')" != "x" ]; then
         typemark='='
      else
         typemark='.'
      fi
   elif [ "${SEARCH_TYPE}" == "-fun" ]; then
      if [ "x$(echo "${templine}" | egrep -i '(function|subroutine|interface)[ ]+'${SEARCH_VAR})" != "x" ]; then
         typemark='C'
      elif [ "x$(echo "${templine}" | egrep -i '^[ ]*end[ ]+(function|subroutine|interface)[ ]+'${SEARCH_VAR})" != "x" ]; then
         typemark='E'
      else
         typemark='.'
      fi
   else
      if [ "x$(echo "${templine}" | egrep -i 'module[ ]+'${SEARCH_VAR})" != "x" ]; then
         typemark='C'
      elif [ "x$(echo "${templine}" | egrep -i '^[ ]*end[ ]+module[ ]+'${SEARCH_VAR})" != "x" ]; then
         typemark='E'
      else
         typemark='.'
      fi
   fi
   if [ 1 -eq ${DEF_ONLY} ] && [ "${typemark}" != "C" ]; then
      continue
   fi
   initial=$(echo "${line}" | sed -e 's/\([^:]*:[0-9]\+:\).*/\1/')
   echo "$(echo "${typemark}:${initial}" | sed -e "${highlightinitial}")$(echo "${templine}" | sed -e "${highlightname}")"
done < <(egrep -rIin ${SEARCH_START_COND}${SEARCH_VAR}${SEARCH_END_COND} ${FORT_ROOT} | sort -V)
# Use version sort to keep order in regard to line numbers for matches within a given filename

exit 0

# If the color coding of the output should be removed (e.g. for further shell processing)
# one possibility is to pass the output to  "sed -e 's/\x1b\[[0-9;]*[JKmsu]//g'" first
