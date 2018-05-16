#!/bin/sh

###############################################################################
# 
# SVN versioning :
#	  @author Renaud Manus, renaud.manus -at- gmail.com
#	  @version $Id$
# 
#   First, update your ~/.subversion/config with the following info:
#   [miscellany]
#   enable-auto-props = yes
#
#   [auto-props]
#   *.sh = svn:keywords=Id
# 
###############################################################################

SetGlobals()
{
	# Set the external commands path, they could be used to initialize the
	# following variables.
	ExternalCommands

	# Set Global variables

	trap Final_Cleanup INT QUIT TERM
}

ExternalCommands()
{
	CAT=/bin/cat
	CHKCONFIG=/sbin/chkconfig
	CHMOD=/bin/chmod
	CP=/bin/cp
	DF=/bin/df
	ECHO='/bin/echo -e'
	GREP=/bin/grep
	KILL=/bin/kill
	MKDIR=/bin/mkdir
	MKTEMP=/bin/mktemp
	MOUNT=/bin/mount
	PERL=/usr/bin/perl
	PS="/bin/ps auxw"
	RM=/bin/rm
}


###############################################################################
#
# echo depending on the verbosity
# Usage : Verbose [echo option]* string*
# Example : Verbose -n '  abcd'  
#           outputs 
#           	'   abcd' 
#           without a \n if $VERBOSE is not null
#
###############################################################################
Verbose()
{
	[ -z "$VERBOSE" ] && return

	$ECHO "$@"
}


###############################################################################
#
#
#
###############################################################################
Final_Cleanup()
{
	# Disable the trap management
	trap - INT QUIT TERM

	# Delete the temporary directory
	if [ -n "$TMP_DIR" ] ; then
		if [ -n "$DEBUG" ] ; then
			$ECHO "Temporary directory [$TMP_DIR] not deleted in debug mode."
		else
			$RM -rf $TMP_DIR
		fi
	fi
}

###############################################################################
# Output an error message on STDERR and exit. The status is 1 by default, it 
# can be specified using "--status <actual status>" as the first parameters :
# Fatal [--status <status>] "message"
###############################################################################
Fatal()
{
	[ "$1" == "--status" ] && shift && STATUS=$1 && shift
	[ -z "$STATUS" ] && STATUS=1
	$ECHO "$*" >&2
	Final_Cleanup
	exit $STATUS
}


###############################################################################
#
# Execute a command, or display it in noexec mode 
# Exec : die if the command output status is not null 
# Run  : do not die if the status is not null 
# If the first argument is --exec, the global $EXEC variable is ignored.
#
###############################################################################
Run()
{
	FORCE_EXEC=
	[ "$1" == '--exec' ] && FORCE_EXEC=1 && shift

	# Simply display the command in noexec mode
	[ -z "$EXEC" -a -z "$FORCE_EXEC" ] && $ECHO "[noexec] $@" && return 0

	# Or execute
	eval "$@"
	return $?
}

Exec()
{
	Run "$@"
	status=$?
	[ $status -ne 0 ] && Fatal "$@ ended with status $status"

	return 0
}

###############################################################################
#
# Usage clause
#
###############################################################################
Usage()
{
	status=$1
	[ -z "$status" ] && status=1

	Fatal --status $status "Usage : $pgm --some_function <options>

Functions
=========

Common options
==============
-d | --debug		: switch to debug mode (set -xv).
			  If used twice (--debug --debug), run the sub-processes in debug mode too.
--[no]exec		: actually execute what should be done
--[no]force		: force the execution of some actions. Use at your own risks...
-[n]v | --[no]verbose
-h | --help
"
}


###############################################################################
#
# Options parsing
#
###############################################################################

Options()
{
	# Action booleans, set to a non-null value if required
	b_Usage=

	DEBUG_LEVEL=0
	DEBUG=
	DEBUG_OPT=
	EXEC=
	FORCE=
	START=
	VERBOSE=true

	while [ $# -gt 0 ] ; do
		opt=$1
		shift
		case "$opt" in
			-d|--debug)
				# At runlevel 1, trace this script only. At runlevel 2, trace
				# the remotely called scripts too.
				DEBUG=true
				DEBUG_LEVEL=`expr $DEBUG_LEVEL + 1`
				set -xv
				[ $DEBUG_LEVEL -gt 1 ] && DEBUG_OPT=--debug
				;;
			--exec)
				EXEC=true
				;;
			--noexec)
				EXEC=
				;;
			--force)
				FORCE=1
				;;
			--noforce)
				FORCE=
				;;
			-h|--help)
				b_Usage=1
				;;
			-v|--verbose)
				VERBOSE=true
				;;
			-nv|--noverbose)
				VERBOSE=
				;;
			*)
				Fatal "Unknown option [$opt]. Consider -h or --help to get help."
				;;
		esac
	done

	# Order the actions
	ACTIONS=
	# ie.
	# 	[ -n "$b_Wipeout_mail_filter" -a -z "$b_Wipeout" ] \
	#		&& ACTIONS="$ACTIONS Wipeout_mail_filter"

	# Default to Usage if no action specified.
	[ -z "$ACTIONS" -o -n "$b_Usage" ] && ACTIONS=Usage 
}

###############################################################################
#
# Warn if ran in no-exec mode
#
###############################################################################
WarnNoExec()
{
	[ -z "$WARNED_NOEXEC" -a -z "$EXEC" ] && $ECHO "   WARNING : running in no-exec mode.\n"
	WARNED_NOEXEC=1
}


###############################################################################
#
#  MAIN
#
###############################################################################

ORIGINAL_CMD="$0 $@"
ORIGINAL_ARGS="$@"
PGM=$0
pgm=`basename $PGM`
TIMESTAMP=`date +%Y%m%d-%H%M%S`
WHOAMI=`whoami`

Options $*
SetGlobals

# Actions execution : they've been sorted after the parsing of the options, 
# just run them and halt if any ends in error.
WARNED_NOEXEC=
next_action=
for ACTION in $ACTIONS ; do
	[ -n "$next_action" ] && $ECHO "====================================\n\n"
	$ACTION
	STATUS=$?
	[ -z "$STATUS" ] && STATUS=0
	[ $STATUS -ne 0 ] && break
	next_action=1
done
Final_Cleanup
[ -n "$WARNED_NOEXEC" -a -z "$EXEC" ] \
	&& $ECHO "\nWARNING : ran in no-exec mode, use --exec for actually executing :\n$ORIGINAL_CMD --exec\n"
exit $STATUS
