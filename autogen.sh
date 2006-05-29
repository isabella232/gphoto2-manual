#!/bin/sh
# autogen.sh - initialize and clean automake&co based build trees
#
# For more detailed info, run "autogen.sh --help" or scroll down to the
# print_help() function.


if test "$(pwd)" != "`pwd`"
then
	echo "Urgh. Dinosaur shell, eh?"
	exit 1
fi


########################################################################
# Constant and initial values

debug="false"
recursive="false"
dryrun="false"
self="$(basename "$0")"
autogen_version="0.4.7"


########################################################################
# Print help message

print_help() {
    cat<<__HELP_EOF__
${self} - initialize automake/autoconf/gettext/libtool based build system

Usage:
    ${self} [<command>|<flag>|...] [<directory>...]

Runs given command sequence on all given directories, in sequence.
If there is no command given, --init is assumed.
If there is no directory given, the location of ${self} is assumed.

Commands:
    --help
        Print this help text
    --version
        Print the tool versions

    --clean
        Clean all files and directories generated by "$self --init"
    --init
        Converts untouched CVS checkout into a build tree which
        can be processed further by running the classic
          ./configure && make && make install

Flags:
    --verbose
        Verbose output
    --dry-run
        Only print the commands to be run, not actually execute
        them.
    --recursive
        Used internally. Do everything which doesn't recurse on
        its own.

${self} depends on automake, autoconf, libtool and gettext.

You may want to set AUTOCONF, AUTOHEADER, AUTOMAKE, AUTORECONF, ACLOCAL,
AUTOPOINT, LIBTOOLIZE to use specific version of these tools, and
AUTORECONF_OPTS to add options to the call to autoreconf.

If none of these variables are set, ${self} tries to find the most
adequate version in \$PATH.
__HELP_EOF__
}


########################################################################
# Print software versions

print_versions() {
    echo "${self} (ndim's autogen) ${autogen_version}"
    for tool in \
	"${AUTOCONF-autoconf}" \
	"${AUTOMAKE-automake}" \
	"${AUTOPOINT-autopoint}" \
	"${LIBTOOLIZE-libtoolize}"
    do
    	"$tool" --version 2>&1 | sed '1q'
    done
}


########################################################################
# Initialize variables for configure.{in,ac} in $1

init_vars() {
    dir="$1"
    echo -n "Looking for \`${dir}/configure.{ac,in}'..."
    # There are shells which don't understand {,} wildcards
    CONFIGURE_AC=""
    for tmp in "${dir}/configure.ac" "${dir}/configure.in"; do
	if test -f "$tmp"; then
	    CONFIGURE_AC="$tmp"
	    echo " $tmp"
	    break
	fi
    done
    if test "x$CONFIGURE_AC" = "x"; then
	echo " no."
	exit 1
    fi

    if "$debug"; then
	if test "$(uname -o)" = "Cygwin"; then
	    # Cygwin autoreconf doesn't understand -Wall
	    AUTORECONF_OPTS="$AUTORECONF_OPTS --verbose"
	else
	    AUTORECONF_OPTS="$AUTORECONF_OPTS --verbose -Wall"
	fi
    fi

    "$debug" && echo -n "Initializing variables for \`${dir}'..."
    # FIXME: Just getting those directories and cleaning them isn't enough.
    #        OK, the "init" part is done recursively by autopoint, so that is easy.
    #        But the cleaning should also work recursively, but that is difficult
    #        with the current structure of the script.
    AG_SUBDIRS="$(for k in $(sed -n 's/^[[:space:]]*GP_AUTOGEN_SUBDIR(\[\{0,1\}\([^])]*\).*/\1/p' "$CONFIGURE_AC"); do echo "${k}"; done)"
    AG_LIBLTDL_DIR="$(sed -n 's/^[[:space:]]*AC_LIBLTDL_\(INSTALLABLE\|CONVENIENCE\)(\[\{0,1\}\([^])]*\).*/\2/p' < "$CONFIGURE_AC")"
    if test "x$AG_LIBLTDL_DIR" = "x"; then
        tmp="$(sed -n 's/^[[:space:]]*\(AC_LIBLTDL_\)\(INSTALLABLE\|CONVENIENCE\)(\[\{0,1\}\([^])]*\).*/\1/p' < "$CONFIGURE_AC")"
	if test "x$tmp" = "xAC_LIBLTDL_"; then
            AG_LIBLTDL_DIR="libltdl"
	else
	    AG_LIBLTDL_DIR=""
	fi
    fi
    AG_AUX="$(sed -n 's/^AC_CONFIG_AUX_DIR(\[\{0,1\}\([^])]*\).*/\1/p' < "$CONFIGURE_AC")"
    if test "x$AG_AUX" = "x"; then
	AG_AUX="."
    fi
    AG_CONFIG_H="$(sed -n 's/^\(A[CM]_CONFIG_HEADERS\?\)(\[\{0,1\}\([^]),]*\).*/\2/p' < "$CONFIGURE_AC")"
    AG_CONFIG_K="$(sed -n 's/^\(A[CM]_CONFIG_HEADERS\?\)(\[\{0,1\}\([^]),]*\).*/\1/p' < "$CONFIGURE_AC")"
    if echo "x$AG_CONFIG_H" | grep -q ':'; then
	echo "$AG_CONFIG_K contains unsupported \`:' character: \`$AG_CONFIG_H'"
	exit 13
    fi
    if test "x$AG_CONFIG_H" != "x"; then
	AG_CONFIG_DIR="$(dirname "${AG_CONFIG_H}")"
	AG_GEN_CONFIG_H="${AG_CONFIG_H} ${AG_CONFIG_H}.in ${AG_CONFIG_DIR}/stamp-h1 ${AG_CONFIG_DIR}/stamp-h2"
    else
	AG_CONFIG_DIR=""
	AG_GEN_CONFIG_H=""
    fi
    for d in "$AG_AUX" "$AG_CONFIG_DIR"; do
	if test -n "$d" && test ! -d "$d"; then
	    mkdir "$d"
	fi
    done
    AG_GEN_ACAM="aclocal.m4 configure $AG_AUX/config.guess $AG_AUX/config.sub $AG_AUX/compile"
    AG_GEN_RECONF="$AG_AUX/install-sh $AG_AUX/missing $AG_AUX/depcomp"
    AG_GEN_LIBTOOL="$AG_AUX/ltmain.sh libtool"
    while read file; do
	AG_GEN_LIBTOOL="${AG_GEN_LIBTOOL} ${AG_LIBLTDL_DIR}/${file}"
    done <<EOF
aclocal.m4
config.guess
config-h.in
config.sub
configure
configure.ac
COPYING.LIB
install-sh
ltdl.c
ltdl.h
ltmain.sh
Makefile.am
Makefile.in
missing
README
EOF
    AG_GEN_GETTEXT="$AG_AUX/mkinstalldirs $AG_AUX/config.rpath ABOUT-NLS"
    while read file; do
	AG_GEN_GETTEXT="${AG_GEN_GETTEXT} m4/${file} m4m/${file}"
    done <<EOF
codeset.m4
gettext.m4
glibc21.m4
iconv.m4
intdiv0.m4
intmax.m4
inttypes-pri.m4
inttypes.m4
inttypes_h.m4
isc-posix.m4
lcmessage.m4
lib-ld.m4
lib-link.m4
lib-prefix.m4
longdouble.m4
longlong.m4
nls.m4
po.m4
printf-posix.m4
progtest.m4
signed.m4
size_max.m4
stdint_h.m4
uintmax_t.m4
ulonglong.m4
wchar_t.m4
wint_t.m4
xsize.m4
EOF
    while read file; do
	AG_GEN_GETTEXT="${AG_GEN_GETTEXT} po/${file}"
    done <<EOF
Makefile.in.in
Makevars.template
Rules-quot
boldquot.sed
en@boldquot.header
en@quot.header
insert-header.sin
quot.sed
remove-potcdate.sin
stamp-po
EOF
    AG_GEN_CONF="config.status config.log"
    AG_GEN_FILES="$AG_GEN_ACAM $AG_GEN_RECONF $AG_GEN_GETTEXT"
    AG_GEN_FILES="$AG_GEN_FILES $AG_GEN_CONFIG_H $AG_GEN_CONF $AG_GEN_LIBTOOL"
    AG_GEN_DIRS="autom4te.cache ${AG_LIBLTDL_DIR}/autom4te.cache ${AG_LIBLTDL_DIR}"
    "$debug" && echo " done."

    if "$debug"; then set | grep '^AG_'; fi
    dryrun_param=""
    if "$dryrun"; then dryrun_param="--dry-run"; fi
}


########################################################################
# Print command to be executed and, if not dryrun, actually execute it.

execute_command() {
    if "$dryrun" || "$debug"; then
	echo "Running <<" "$@" ">>"
    fi
    if "$dryrun"; then :; else
	"$@"
    fi
}


########################################################################
# Clean generated files from $* directories

command_clean() {
    if test "x$AG_GEN_FILES" = "x"; then echo "Internal error"; exit 2; fi
    dir="$1"
    #while test "$dir"; do
	echo "$self:clean: Entering directory \`${dir}'"
	(
	    if cd "$dir"; then
		echo -n "Cleaning autogen generated files..."
		execute_command rm -rf ${AG_GEN_DIRS}
		execute_command rm -f ${AG_GEN_FILES}
		echo " done."
		if test -h INSTALL; then execute_command rm -f INSTALL; fi
		echo -n "Cleaning generated Makefile, Makefile.in files..."
		if "$debug"; then echo; fi
		find . -type f -name 'Makefile.am' -print | \
		    while read file; do
		    echo "$file" | grep -q '/{arch}' && continue
		    echo "$file" | grep -q '/\.svn'  && continue
		    echo "$file" | grep -q '/CVS'    && continue
		    base="$(dirname "$file")/$(basename "$file" .am)"
		    if "$debug"; then
			echo -e "  Removing files created from ${file}"
		    fi
		    execute_command rm -f "${base}" "${base}.in"
		done
		if "$debug"; then :; else echo " done."; fi
		echo -n "Removing *~ backup files..."
		find . -type f -name '*~' -print | while read fname; do
		    execute_command rm -f "$fname"
		done
		echo " done."
		if test -n "${AG_SUBDIRS}"; then
		    "$0" --clean ${dryrun_param} --recursive ${AG_SUBDIRS}
		fi
	    fi
	)
	echo "$self:clean: Left directory \`${dir}'"
	#shift
	#dir="$1"
    #done
}


########################################################################
# Initialize build system in $1 directory

command_init() {
    dir="$1"
    if test "x$AG_GEN_FILES" = "x"; then echo "Internal error"; exit 2; fi
    echo "$self:init: Entering directory \`${dir}'"
(
if cd "${dir}"; then
    if test "x$AG_LIBLTDL_DIR" != "x"; then
	# We have to run libtoolize --ltdl ourselves because
	#   - autoreconf doesn't run it at all
	execute_command "${LIBTOOLIZE-"libtoolize"}" --ltdl --copy
	# And we have to clean up the generated files after libtoolize because
	#   - we still want symlinks for the files
	#   - but we want to (implicitly) AC_CONFIG_SUBDIR and that writes to
	#     these files.
	if test ! -d "${AG_LIBLTDL_DIR}" || test ! -f "${AG_LIBLTDL_DIR}/Makefile.am"; then
		echo "Could not create libltdl directory \`${AG_LIBLTDL_DIR}'."
		echo "Leaving \`$(pwd)' and aborting."
		exit 2
	fi
	(cd "${AG_LIBLTDL_DIR}" && execute_command rm -f aclocal.m4 config.guess config.sub configure install-sh ltmain.sh Makefile.in missing)
    fi
    if test -n "${AG_SUBDIRS}"; then
	"$0" --init ${dryrun_param} --recursive ${AG_SUBDIRS}
	status="$?"
	if test "$status" -ne 0; then exit "$status"; fi
    fi
    if "$recursive"; then :; else
	if execute_command ${AUTORECONF-"autoreconf"} --install --symlink ${AUTORECONF_OPTS}; then
	    :; else
	    status="$?"
	    echo "autoreconf quit with exit code $status, aborting."
	    exit "$status"
	fi    
	echo "You may run ./configure now in \`${dir}'."
	echo "Run as \"./configure --help\" to find out about config options."
    fi
else
    exit "$?"
fi
)
    # Just error propagation
    status="$?"
    echo "$self:init: Left directory \`${dir}'"
    if "$recursive"; then 
    	:
    elif test "$status" -ne "0"; then
	exit "$status"
    fi
}


########################################################################
# If not explicitly given, try to find most convenient tools in $PATH
#
# This method only works for tools made for parallel installation with
# a version suffix, i.e. autoconf and automake.
#
# libtool and gettext do not support that, so you'll still have to
# manually set the respective variables if the default does not work
# for you.

skip="false"
oldversion="oldversion"
while read flag variable binary version restofline; do
	case "$flag" in
	+)
		if "$skip"; then skip=false; fi
		if test -n "`eval echo \$\{$variable+"set"\}`"; then
			skip=:
		else
			if test -x "`which ${binary}${version} 2> /dev/null`"; then
				export "$variable"="${binary}${version}"
				oldversion="${version}"
			else
				skip=:
			fi
		fi
		;;
	-)
		if "$skip"; then :; else
			export "$variable"="${binary}${oldversion}"
		fi
		;;
	esac
done<<EOF
+ AUTOMAKE	automake	-1.9
- ACLOCAL	aclocal
+ AUTOMAKE	automake	-1.8
- ACLOCAL	aclocal
+ AUTOCONF	autoconf	2.59
- AUTOHEADER	autoheader
- AUTORECONF	autoreconf
+ AUTOCONF	autoconf	2.50
- AUTOHEADER	autoheader
- AUTORECONF	autoreconf
EOF


########################################################################
# Parse command line.
# This still accepts more than the help text says it does, but that
# isn't supported.

commands="init" # default command in case none is given
pcommands=""
check_versions=false
dirs="$(dirname "$0")"
#dirs="$(cd "$dirs" && pwd)"
pdirs=""
# Yes, unquoted $@ isn't space safe, but it works with simple shells.
for param in $@; do
    case "$param" in
	--clean)
	    pcommands="$pcommands clean"
	    ;;
	--init)
	    pcommands="$pcommands init"
	    check_versions=:
	    ;;
	--verbose)
	    debug=:
	    ;;
	--dry-run)
	    dryrun=:
	    ;;
	--recursive)
	    recursive=:
	    ;;
	--version)
	    print_versions
	    exit 0
	    ;;
	-h|--help)
	    print_help
	    exit 0
	    ;;
	-*)
	    echo "Unhandled $self option: $param"
	    exit 1
	    ;;
	*)
	    pdirs="${pdirs} ${param}"
	    ;;
    esac
done
if test "x$pcommands" != "x"; then
    # commands given on command line? use them!
    commands="$pcommands"
else
    check_versions=:
fi
if test "x$pdirs" != "x"; then
    # dirs given on command line? use them!
    dirs="$pdirs"
fi


########################################################################
# Check that tool versions satisfy our needs

if "$check_versions"; then
	# check tool versions
	errors=false
	lf="
"
	while read tool minversion package; do
		version="$("$tool" --version | sed 's/^.*(.*) *\(.*\)$/\1/g;1q')"
		# compare version and minversion
		first="$(echo "$version$lf$minversion" | sort -n | sed '1q')"
		if test "x$minversion" != "x$first" && test "x$version" = "x$first"; then
			echo "Version \`$version' of \`$tool' from the \`$package' (dev/devel) package is not sufficient."
			echo "At least \`$minversion' required."
			errors=:
		fi
	done <<EOF
${ACLOCAL-"aclocal"}	1.8	automake
${AUTOMAKE-"automake"}	1.8	automake
${AUTOCONF-"autoconf"}	2.59	autoconf
${AUTOHEADER-"autoheader"}	2.59	autoconf
${AUTOPOINT-"autopoint"}	0.14.1	gettext
${LIBTOOLIZE-"libtoolize"}	1.4	libtool
EOF
	if "$errors"; then
		echo "Please update your toolset."
		echo "If you want to continue regardless of your old toolset, press ENTER."
		read
	fi
fi


########################################################################
# Actually run the commands

for dir in ${dirs}; do
    "$debug" && echo "Running commands on directory \`${dir}'"
    if test ! -d "$dir"; then
	echo "Could not find directory \`${dir}'"
    else
	init_vars "$dir"
	for command in ${commands}; do
	    "command_$command" "$dir"
	done
    fi
done

exit 0

# Please do not remove this:
# filetype: 89b1e88e-4cf2-44f1-980d-730067367775
# I use this to find all the different instances of this file which 
# are supposed to be synchronized.
