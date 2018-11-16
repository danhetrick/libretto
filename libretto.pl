#!/usr/bin/perl
#
# ██╗     ██╗██████╗ ██████╗ ███████╗████████╗████████╗ ██████╗ 
# ██║     ██║██╔══██╗██╔══██╗██╔════╝╚══██╔══╝╚══██╔══╝██╔═══██╗
# ██║     ██║██████╔╝██████╔╝█████╗     ██║      ██║   ██║   ██║
# ██║     ██║██╔══██╗██╔══██╗██╔══╝     ██║      ██║   ██║   ██║
# ███████╗██║██████╔╝██║  ██║███████╗   ██║      ██║   ╚██████╔╝
# ╚══════╝╚═╝╚═════╝ ╚═╝  ╚═╝╚══════╝   ╚═╝      ╚═╝    ╚═════╝ 
#
#	Libretto IRC Bot Programming Language
#	Copyright (C) 2018  Daniel Hetrick
#
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <https://www.gnu.org/licenses/>.


use strict;

my $APPLICATION						= 'Libretto';
my $VERSION							= '0.08448';
my $URL								= 'https://github.com/danhetrick';
my $CODENAME						= 'aria';
my $RELEASE_TYPE					= 'alpha';

# ========================
# | CORE LIBRARIES BEGIN |
# ========================

use FindBin qw($Bin $RealBin);
use File::Spec;
use LWP::Simple;
use Getopt::Long;
use File::Path qw(make_path remove_tree);
use MIME::Base64;
use Digest::SHA qw(sha256 sha256_hex sha256_base64 sha512 sha512_hex sha512_base64 );
use File::Basename;
use Cwd;
use URI::Escape;

# ======================
# | CORE LIBRARIES END |
# ======================

# ========================
# | CPAN LIBRARIES BEGIN |
# ========================

use POE qw(
	Component::IRC::State
	Component::Server::IRC
);

# Run this now; this will suppress POE's warning about a failed startup
# if we have to exit due to bad settings or input before we can begin
POE::Kernel->run();

if(
	eval {
		require JavaScript::V8;
		1;
	}
) {} else {
	print "$APPLICATION requires Google's V8 Javascript engine and JavaScript::V8 to run.\n";
	exit 1;
}

my $SSL_AVAILABLE = undef;
if  (
	eval {
		require POE::Component::SSLify;
		require POE::Filter::SSL;
		1;
	}
) { $SSL_AVAILABLE = 1; }

my $HTTPD_AVAILABLE = undef;
if  (
	eval {
		require POE::Component::Server::TCP;
		require POE::Filter::HTTPD;
		require HTTP::Response;
		1;
	}
) { $HTTPD_AVAILABLE = 1; }

# ======================
# | CPAN LIBRARIES END |
# ======================

use Data::Dumper;

# =========================
# | LOCAL LIBRARIES BEGIN |
# =========================

use lib File::Spec->catfile($RealBin,'lib');

use XML::TreePP;
use Term::ANSIColor qw(:constants colorvalid colored);
use Text::ParseWords;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

# =======================
# | LOCAL LIBRARIES END |
# =======================

# ==========================
# | GLOBAL VARIABLES BEGIN |
# ==========================

# -----------------------------------------------
# | SETTINGS, DEFAULTS, AND OPERATING VARIABLES |
# -----------------------------------------------

my $DEFAULT_SOCKS_PORT				= 1080;
my $DEFAULT_IRC_PORT				= 6667;
my $DEFAULT_SSL_IRC_PORT			= 6697;
my $GET_EXTERNAL_IP_ADDRESS			= undef;
my $GET_EXTERNAL_IP_ADDRESS_HOST	= "http://myexternalip.com/raw";
my $VERBOSE							= undef;
my $WARN							= undef;
my $USE_TERM_COLORS					= 1;
my $VERBOSE_COLOR					= 'bold bright_green';
my $ERROR_COLOR						= 'bold bright_red';
my $WARN_COLOR						= 'bold bright_magenta';
my $NO_FLOOD_PROTECTION				= undef;
my $USE_IPV6						= undef;
my $NICKNAME						= undef;
my $IRCNAME							= "$APPLICATION IRC bot $VERSION";
my $USERNAME						= "$APPLICATION";
my $DCC_PORTS						= undef;
my $EXTERNAL_IP						= undef;
my @USE_DCC_PORTS					= (10000 .. 11000);
my $GENERATE_CONNECTION_FILE		= undef;
my $GENERATE_SETTINGS_FILE			= undef;
my $CMDLINE_VERBOSE					= undef;
my $CMDLINE_WARN					= undef;
my $AWAY_POLL_TIME					= 300;
my $UPTIME							= 0;
my $LIBRETTO_SCRIPT					= undef;
my $LIBRETTO_SCRIPT_BASENAME		= undef;
my $ENABLE_DCC						= undef;
my $KERNEL							= undef;
my @EVENT_HOOKS						= ();
my @DELAY							= ();
my $CLOCK_STARTED					= undef;

my @PILE = ();
my @WEBPILE = ();
my @SERVERPILE = ();
my @NEWSERVERS = ();

my %ZIP_FILES = {};

my $BLANK_SETTINGS_FILE = join('',<DATA>);

# Colors for IRC
my $COLOR_TEXT				= chr(3);
my $BOLD_TEXT				= chr(2);
my $ITALIC_TEXT				= chr(hex("1D"));
my $UNDERLINE_TEXT			= chr(hex("1F"));
my $HOST_OS					= "$^O";

use constant HOOK_TYPE				=> 0;
use constant HOOK_ID				=> 1;
use constant HOOK_CODE				=> 2;
use constant ZIP_FILE 				=> 0;
use constant ZIP_FILE_NAME			=> 1;

# -------------------------
# | FILES AND DIRECTORIES |
# -------------------------

# File and directory names
my $SETTINGS_FILE_NAME				= 'settings.xml';
my $FILE_DIRECTORY_NAME				= 'files';

# File and directory locations
my $SETTINGS_FILE					= File::Spec->catfile($RealBin,$SETTINGS_FILE_NAME);
my $FILE_DIRECTORY					= File::Spec->catfile($RealBin,$FILE_DIRECTORY_NAME);

my $STDLIB = File::Spec->catfile($RealBin,'lib','Libretto');

# ----------------------------------------
# | LIBRETTO FUNCTION AND VARIABLE NAMES |
# ----------------------------------------

my $FUNCTION_CONNECT				= 'client';	# connect(obj)
my $FUNCTION_DISCONNECT				= 'disconnect';	# disconnect(server,port)
my $FUNCTION_PRINT					= 'print';		# print("stuff");
my $FUNCTION_VERBOSE				= 'verbose';	# verbose("verbose stuff")
my $FUNCTION_WARN					= 'warn';		# warn("warn stuff")
my $FUNCTION_JOIN					= 'join';		# join(server,port,channel) or join(server,port,channel,password)
my $FUNCTION_PART					= 'part';		# part(server,port,channel) or part(server,port,channel,msg)
my $FUNCTION_MESSAGE				= 'say';		# say(server,port,channel||user,msg)
my $FUNCTION_COLOR					= 'color'; 			# color(foreground,background,text)
my $FUNCTION_ITALIC					= 'italic';			# italic(text)
my $FUNCTION_UNDERLINE				= 'underline';		# underline(text)
my $FUNCTION_BOLD					= 'bold';			# bold(text)
my $FUNCTION_TERMCOLOR				= 'termcolor';		# termcolor(color,text)
my $FUNCTION_TIMESTAMP				= 'timestamp';
my $FUNCTION_ENCODE_BASE64			= 'base64';
my $FUNCTION_DECODE_BASE64			= 'unbase64';
my $FUNCTION_SHA_256				= 'sha256';
my $FUNCTION_SHA_512				= 'sha512';
my $FUNCTION_EXIT					= 'exit';
my $FUNCTION_HOOK					= 'hook';
my $FUNCTION_UNHOOK					= 'unhook';
my $FUNCTION_DELAY					= 'delay';
my $FUNCTION_TOPIC					= 'topic';
my $FUNCTION_NICK					= 'nickname';
my $FUNCTION_CHANNEL				= 'channel';
my $FUNCTION_WHOIS					= 'whois';
my $FUNCTION_RAW					= 'raw';
my $FUNCTION_INCLUDE				= 'use';
my $FUNCTION_EXEC					= 'exec';
my $FUNCTION_TOKENS					= 'tokens';
my $FUNCTION_INVITE					= 'invite';
my $FUNCTION_NOTICE					= 'notice';
my $FUNCTION_SET_MODE				= 'mode';
my $FUNCTION_DCC_SEND				= 'send';
my $FUNCTION_SHUTDOWN				= 'shutdown';
my $FUNCTION_WEBHOOK				= 'webhook';
my $FUNCTION_RECONNECT				= 'reconnect';
my $FUNCTION_SERVER 				= 'server';
my $FUNCTION_ADD_OP					= 'addop';
my $FUNCTION_DEL_OP					= 'deleteop';
my $FUNCTION_ADD_AUTH				= 'addauth';
my $FUNCTION_DEL_AUTH				= 'deleteauth';
my $FUNCTION_FORCE_MODE				= 'forcemode';
my $FUNCTION_FORCE_KICK				= 'forcekick';
my $FUNCTION_FORCE_KILL				= 'forcekill';
my $FUNCTION_ALL_NICKS				= 'allnicks';
my $FUNCTION_ALL_CHANNELS			= 'allchannels';
my $FUNCTION_DCC_CHAT				= 'dcc';
my $FUNCTION_DCC_CLOSE				= 'dcc_close';

# File I/O Functions
my $FUNCTION_WRITE_FILE			= 'fwrite';
my $FUNCTION_READ_FILE			= 'fread';
my $FUNCTION_FILE_EXISTS		= 'isfile';
my $FUNCTION_DELETE_FILE		= 'rmfile';
my $FUNCTION_FILE_SIZE			= 'fsize';
my $FUNCTION_CHMOD				= 'chmod';
my $FUNCTION_FILE_BASENAME 		= 'basename';
my $FUNCTION_FILE_LOCATION 		= 'flocation';
my $FUNCTION_FILE_MODE			= 'fmode';
my $FUNCTION_FILE_PERMISSIONS	= 'fpermissions';
my $FUNCTION_LIST_DIRECTORY		= 'dirlist';
my $FUNCTION_CWD				= 'cwd';
my $FUNCTION_DIRECTORY_EXISTS	= 'isdir';
my $FUNCTION_MAKE_DIRECTORY		= 'mkdir';
my $FUNCTION_MAKE_PATH			= 'mkpath';
my $FUNCTION_DELETE_DIRECTORY	= 'rmdir';
my $FUNCTION_DELETE_PATH		= 'rmpath';
my $FUNCTION_CHANGE_DIRECTORY	= 'cd';
my $FUNCTION_CATDIR				= 'catdir';
my $FUNCTION_CATFILE			= 'catfile';
my $FUNCTION_TEMPDIR			= 'temp';

# Zip file functions
my $FUNCTION_NEW_ZIP			= 'zopen';		# var id = zip_open(FILE)
my $FUNCTION_CLOSE_ZIP			= 'zclose';		# zip_close(id)
my $FUNCTION_SAVE_ZIP			= 'zwrite';		# zip_write(id)
my $FUNCTION_ADD_TO_ZIP			= 'zadd';		# zip_add(id,FILE)
my $FUNCTION_LIST_ZIP_MEMBERS	= 'zlist';		# var file = zip_list(id)
my $FUNCTION_GET_ZIP_MEMBER		= 'zmember';	# var filecontents = zip_contents(id,FILENAME)
my $FUNCTION_EXTRACT_ZIP		= 'zextract';	# zip_extract(id,DIRECTORY)
my $FUNCTION_REMOVE_ZIP_MEMBER	= 'zremove';		# zip_remove(id,FILE)

# Built-in Variable Names
my $VARIABLE_UPTIME					= 'UPTIME';
my $VARIABLE_VERBOSE				= 'VERBOSE';
my $VARIABLE_WARNINGS				= 'WARNINGS';
my $VARIABLE_DCC					= 'DCC';
my $SCRIPT_COMMANDLINE_ARGS_ARRAY	= 'ARGV';
my $VARIABLE_SCRIPT					= 'SCRIPTNAME';
my $VARIABLE_HTTPD					= 'HTTPD';
my $VARIABLE_HOST					= 'HOST';

# Event Hook Names
my $HOOK_PART					= 'part';
my $HOOK_JOIN					= 'join';
my $HOOK_PUBLIC					= 'public';
my $HOOK_PRIVATE				= 'private';
my $HOOK_CONNECT				= 'connect';
my $HOOK_DCC_CHAT_REQUEST		= 'dcc-chat-request';
my $HOOK_DCC_START				= 'dcc-start';
my $HOOK_DCC_INCOMING			= 'dcc-chat';
my $HOOK_DCC_DONE				= 'dcc-done';
my $HOOK_DCC_ERROR				= 'dcc-error';
my $HOOK_DCC_SEND_REQUEST		= 'dcc-send-request';
my $HOOK_DCC_SEND				= 'dcc-send';
my $HOOK_DCC_GET				= 'dcc-get';
my $HOOK_SCRIPT_CONTROL_BEGIN	= 'begin';
my $HOOK_NOX_EXIT				= 'exit';
my $HOOK_TOPIC					= 'topic';
my $HOOK_ACTION					= 'action';
my $HOOK_MODE					= 'mode';
my $HOOK_KICK					= 'kick';
my $HOOK_INVITE					= 'invite';
my $HOOK_NICK					= 'nick-changed';
my $HOOK_NOTICE					= 'notice';
my $HOOK_RAW					= 'raw';
my $HOOK_RAW_OUT				= 'raw-out';
my $HOOK_CHANNEL_MODE			= 'mode-channel';
my $HOOK_USER_MODE				= 'mode-user';
my $HOOK_AWAY					= 'away';
my $HOOK_BACK					= 'back';
my $HOOK_QUIT					= 'quit';
my $HOOK_NICK_IN_USE			= 'nick-taken';


my $HOOK_CLIENT_QUIT			= 'client-quit';
my $HOOK_CLIENT_JOIN			= 'client-join';
my $HOOK_CLIENT_PART			= 'client-part';
my $HOOK_SERVER_ERROR			= 'server-error';
my $HOOK_SERVER_QUIT			= 'server-quit';
my $HOOK_CLIENT_KICK			= 'client-kick';
my $HOOK_CLIENT_TOPIC			= 'client-topic';
my $HOOK_CLIENT_MODE			= 'client-mode';
my $HOOK_CLIENT_CHANNEL_MODE	= 'client-channel-mode';
my $HOOK_SERVER_JOIN			= 'server-join';


# ========================
# | GLOBAL VARIABLES END |
# ========================

# ======================
# | MAIN PROGRAM BEGIN |
# ======================

# Handle command-line options
Getopt::Long::Configure ("bundling");
GetOptions(
    "c|config|configuration=s"		=> \$SETTINGS_FILE,
    "f|files=s"						=> \$FILE_DIRECTORY,
    "C|generate-config:s"			=> \$GENERATE_SETTINGS_FILE,
    "v|verbose"						=> \$CMDLINE_VERBOSE,
    "w|warn"						=> \$CMDLINE_WARN,
    "l|license"						=> sub {
	    	print"$APPLICATION $VERSION ($CODENAME - $RELEASE_TYPE release)\n";
			print"Copyright (C) 2018  Daniel Hetrick\n\n";
			print"This program is free software: you can redistribute it and/or modify\n";
			print"it under the terms of the GNU General Public License as published by\n";
			print"the Free Software Foundation, either version 3 of the License, or\n";
			print"(at your option) any later version.\n\n";
			print"This program is distributed in the hope that it will be useful,\n";
			print"but WITHOUT ANY WARRANTY; without even the implied warranty of\n";
			print"MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n";
			print"GNU General Public License for more details.\n\n";
			print"You should have received a copy of the GNU General Public License\n";
			print"along with this program.  If not, see <https://www.gnu.org/licenses/>.\n";
			exit 0;
		},
    "h|help"						=> sub {
    		print "$APPLICATION $VERSION ($CODENAME - $RELEASE_TYPE release)\n\n";
    		print "\tperl $0 [OPTIONS] SCRIPT [ARGUMENTS]\n\n";
    		print "--(h)elp\t\t\t\tDisplay usage information\n";
    		print "--(v)erbose\t\t\t\tTurn on verbose mode\n";
    		print "--(w)arn\t\t\t\tTurn on warnings mode\n";
    		print "--(l)icense\t\t\t\tDisplays license information\n";
    		print "--(c)onfiguration FILE\t\t\tSets the file to load settings from\n";
    		print "--(f)iles DIRECTORY\t\t\tSets the directory to place uploaded files\n";
    		print "                   \t\t\tand look for files for users to download\n";
    		print "--generate-(C)onfig [FILE]\t\tGenerates a generic setting config file\n\n";

    		print "Single letter options can be bundled; for example to turn on both\n";
    		print "verbose and warnings mode, you can pass $0 the option \"-vw\".\n";

    		exit 0;
    	},
);

# Handle any options that relate to generating XML
if(defined $GENERATE_SETTINGS_FILE){
	if(length $GENERATE_SETTINGS_FILE){
		open(FILE,">$GENERATE_SETTINGS_FILE") or display_error("Error writing config template file to \"$GENERATE_SETTINGS_FILE\"") && exit 1; 1;
		print FILE $BLANK_SETTINGS_FILE;
		close FILE;
		exit 0;
	} else {
		print $BLANK_SETTINGS_FILE;
		exit 0;
	}
}

# Check to make sure any settings from the command-line
# are sane.
if((-e $SETTINGS_FILE)&&(-f $SETTINGS_FILE)){}else{
	display_error("\"$SETTINGS_FILE\" doesn't exist or is not a file.");
}
if((-e $FILE_DIRECTORY)&&(-d $FILE_DIRECTORY)){}else{
	print "\"$FILE_DIRECTORY\" doesn't exist. Create? Y/N (N): ";
	my $res = <STDIN>; chomp $res; $res = lc($res);
	if(($res eq 'y')||($res eq 'yes')){
		mkdir $FILE_DIRECTORY;
	} else {
		display_error("\"$FILE_DIRECTORY\" doesn't exist or is not a directory.");
	}
}

# Load settings from the configuration file.
load_configuration_file($SETTINGS_FILE);

# Check the arguments passed to Libretto, and make sure that
# at least one argument (the script to run) was passed.
if(scalar @ARGV>=1){
	$LIBRETTO_SCRIPT = shift @ARGV;
	if((-e $LIBRETTO_SCRIPT)&&(-f $LIBRETTO_SCRIPT)){
		$LIBRETTO_SCRIPT_BASENAME = basename($LIBRETTO_SCRIPT);
	}else{
		display_error("File \"$LIBRETTO_SCRIPT\" not found.");
	}
}else{
	display_error("No script to load. Try \"perl $0 --help\" for usage information.");
}

# If verbosity or warnings mode has been turned on via
# commandline options, make sure it's honored
if($CMDLINE_VERBOSE){ $VERBOSE = 1; }
if($CMDLINE_WARN){ $WARN = 1; }

verbose("$APPLICATION $VERSION");

# If the "get external IP address" option is turned on,
# grab the external IP from the set host
if($GET_EXTERNAL_IP_ADDRESS){
	verbose("Retrieving external IP address...");
	my $ip = LWP::Simple::get($GET_EXTERNAL_IP_ADDRESS_HOST);
	$EXTERNAL_IP = $ip;
	verbose("External IP address retrieved: $EXTERNAL_IP");
}

# Create the JavaScript::V8::Context object we're going to use for the bot
# This object will not be used directly; if we need to execute JS code,
# call the execute_javascript() subroutine.
my $JAVASCRIPT = create_javascript_context();

# Load our script into memory
my $fs = bytes_to_human_readable(-s $LIBRETTO_SCRIPT);
verbose("Loading script \"$LIBRETTO_SCRIPT\" ($fs)");
open(FILE,"<$LIBRETTO_SCRIPT") or display_error("Error reading \"$LIBRETTO_SCRIPT\" ($!)");
$LIBRETTO_SCRIPT = join('',<FILE>);
close FILE;

# Handle commandline arguments
# Any arguments passed to Libretto, past the script name, are passed along
# to the script in a JS array named 'ARGV'.
if(scalar @ARGV>=1){
	my @jsargs = ();
	foreach my $a (@ARGV){
		$a = quotemeta($a);
		push(@jsargs,'"'.$a.'"');
	}
	my $arg_code = 'var '.$SCRIPT_COMMANDLINE_ARGS_ARRAY.' = ['.join(',',@jsargs).'];';
	execute_javascript($arg_code);
} else {
	my $arg_code = 'var '.$SCRIPT_COMMANDLINE_ARGS_ARRAY.' = new Array();';
	execute_javascript($arg_code);
}

# Built-in variables
#verbose("Assigning built-in variables...");
if($VERBOSE){ execute_javascript("const $VARIABLE_VERBOSE = true;"); } else { execute_javascript("const $VARIABLE_VERBOSE = false;"); }
if($WARN){ execute_javascript("const $VARIABLE_WARNINGS = true;"); } else { execute_javascript("const $VARIABLE_WARNINGS = false;"); }
if($ENABLE_DCC){ execute_javascript("const $VARIABLE_DCC = true;"); } else { execute_javascript("const $VARIABLE_DCC = false;"); }
if($HTTPD_AVAILABLE){ execute_javascript("const $VARIABLE_HTTPD = true;"); } else { execute_javascript("const $VARIABLE_HTTPD = false;"); }
execute_javascript("var $VARIABLE_UPTIME = 0;");
execute_javascript("const $VARIABLE_SCRIPT = \"$LIBRETTO_SCRIPT_BASENAME\";");
execute_javascript("const $VARIABLE_HOST = \"$HOST_OS\";");

my $colorvars = <<'EOC';
const WHITE = "00";
const BLACK = "01";
const BLUE = "02";
const GREEN = "03";
const RED = "04";
const BROWN = "05";
const PURPLE = "06";
const ORANGE = "07";
const YELLOW = "08";
const LIGHT_GREEN = "09";
const TEAL = "10";
const CYAN = "11";
const LIGHT_BLUE = "12";
const PINK = "13";
const GREY = "14";
const LIGHT_GREY = "15";
EOC

execute_javascript("$colorvars");

# Execute our script
#verbose("Executing script \"$LIBRETTO_SCRIPT_BASENAME\" (".bytes_to_human_readable(length($LIBRETTO_SCRIPT)).")");
execute_javascript($LIBRETTO_SCRIPT);

# Now that all our POE:Component::IRC "objects" are set up, let's
# set up our POE session and all the events we want to receive
POE::Session->create(
	package_states =>
		[ 'main' => [qw(_start irc_001 irc_public irc_msg irc_join
						irc_part irc_433 irc_ctcp_action _beat
						irc_registered _default irc_dcc_start irc_dcc_done
						irc_dcc_chat irc_dcc_error irc_dcc_request irc_topic
						irc_mode irc_kick irc_invite irc_nick irc_notice
						irc_raw irc_raw_out irc_dcc_get irc_dcc_send irc_quit
						irc_user_away irc_user_back irc_chan_mode irc_user_mode
						ircd_daemon_server ircd_daemon_nick ircd_daemon_quit
						ircd_daemon_notice ircd_daemon_privmsg ircd_daemon_join
						ircd_daemon_umode ircd_daemon_part ircd_daemon_error
						ircd_daemon_squit ircd_daemon_kick ircd_daemon_mode
						ircd_daemon_topic ircd_daemon_public ircd_daemon_invite
						)], ],
);

# Start up the POE kernel!
$poe_kernel->run();
exit 0;

# ====================
# | MAIN PROGRAM END |
# ====================

# ====================================
# | POE::COMPONENT::IRC EVENTS BEGIN |
# ====================================

sub _default {

	# Uncomment the below code to see every bit of data sent
	# to us from the IRC server

    # my ($event, $args) = @_[ARG0 .. $#_];
    # my @output = ( "$event: " );
 
    # for my $arg (@$args) {
    #     if ( ref $arg eq 'ARRAY' ) {
    #         push( @output, '[' . join(', ', @$arg ) . ']' );
    #     }
    #     else {
    #         push ( @output, "'$arg'" );
    #     }
    # }
    # print join ' ', @output, "\n";

    undef;
}

sub _beat {
	my ( $kernel, $heap, $session ) = @_[ KERNEL, HEAP, SESSION ];

	$UPTIME += 1;

	if($JAVASCRIPT){
		execute_javascript("$VARIABLE_UPTIME = $UPTIME;"); 
	}

	my @clean = ();
	foreach my $e (@DELAY){
		my ($time,$func)=@{$e};
		if($time<=$UPTIME){
			&$func();
			next;
		}
		push(@clean,$e);
	}
	@DELAY = @clean;

	$kernel->delay( _beat => 1 );

}

sub _start {
	my ( $kernel, $heap, $sender, $session ) = @_[ KERNEL, HEAP, SENDER, SESSION ];

	$kernel->signal( $kernel, 'POCOIRC_REGISTER', $session->ID(), 'all' );

	foreach my $ea (@NEWSERVERS){
		my @e = @{$ea};
		$e[0]->add_listener(port => "$e[1]");
		$e[0]->yield('register', 'all');
		$e[0]->{hostID} = $e[1];
		my @es = ($e[1],$e[0]);
		push(@SERVERPILE,\@es);
	}
	@NEWSERVERS = ();

	if($CLOCK_STARTED){}else{
		$CLOCK_STARTED = 1;
		$kernel->delay( _beat => 1 );
	}
}

sub irc_registered {
	my ( $kernel, $heap, $sender, $irc_object ) =
		@_[ KERNEL, HEAP, SENDER, ARG0 ];
	my $alias = $irc_object->session_alias();

	$irc_object->yield( connect => { } );

	#verbose("Connecting bot to IRC server $alias");

}

sub irc_001 {
	my ( $kernel, $heap, $sender ) = @_[ KERNEL, HEAP, SENDER ];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	$KERNEL = $kernel;

	verbose("Connected!");

	foreach my $h (@{get_hooks($HOOK_CONNECT)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			&$h(\%args);
		}
	}

}

sub irc_chan_mode {
	my ( $kernel, $sender, $who, $channel, $mode ) =
		@_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my @ARGS = @_[ ARG3 .. $#_ ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";
	my $arguments = join(' ',@ARGS);
	my $alias = "$sender";

	verbose("$nick($hostmask) set channel mode $mode on $channel ($arguments)");

	foreach my $h (@{get_hooks($HOOK_CHANNEL_MODE)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Mode'} = "$mode";
			$args{'Arguments'} = "$arguments";
			$args{'Channel'} = "$channel";
			&$h(\%args);
		}
	}

}

sub irc_user_mode {
	my ( $kernel, $sender, $who, $user, $mode ) =
		@_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my @ARGS = @_[ ARG3 .. $#_ ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";
	my $arguments = join(' ',@ARGS);

	verbose("$nick($hostmask) set user mode $mode on $user ($arguments)");

	foreach my $h (@{get_hooks($HOOK_USER_MODE)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Mode'} = "$mode";
			$args{'Arguments'} = "$arguments";
			$args{'Target'} = "$user";
			&$h(\%args);
		}
	}

}

sub irc_user_away {
	my ( $kernel, $sender, $who ) =
		@_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	verbose("$who is away");

	foreach my $h (@{get_hooks($HOOK_AWAY)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$who";
			&$h(\%args);
		}
	}
}

sub irc_user_back {
	my ( $kernel, $sender, $who ) =
		@_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	verbose("$who is back");

	foreach my $h (@{get_hooks($HOOK_BACK)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$who";
			&$h(\%args);
		}
	}
}

sub irc_quit {
	my ( $kernel, $sender, $who, $msg ) =
		@_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	if($msg ne ''){
		verbose("$nick($hostmask) quit IRC ($msg)");
	} else {
		verbose("$nick($hostmask) quit IRC");
	}

	foreach my $h (@{get_hooks($HOOK_QUIT)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Message'} = "$msg";
			&$h(\%args);
		}
	}
}


sub irc_join {
	my ( $kernel, $sender, $who, $where ) =
		@_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	verbose("$nick($hostmask) joined $where");

	foreach my $h (@{get_hooks($HOOK_JOIN)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$where";
			&$h(\%args);
		}
	}

}

sub irc_part {
	my ( $kernel, $sender, $who, $where, $msg ) =
		@_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	if($msg ne ''){
		verbose("$nick($hostmask) left $where ($msg)");
	} else {
		verbose("$nick($hostmask) left $where");
	}

	foreach my $h (@{get_hooks($HOOK_PART)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$where";
			$args{'Message'} = "$msg";
			&$h(\%args);
		}
	}
}

sub irc_msg {
	my ( $kernel, $sender, $who, $where, $what ) =
		@_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	verbose("$server_name PRIVATE $nick($hostmask): $what");

	foreach my $h (@{get_hooks($HOOK_PRIVATE)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Message'} = "$what";
			&$h(\%args);
		}
	}

}

sub irc_public {
	my ( $kernel, $sender, $who, $where, $what ) =
		@_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $channel = $where->[0];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	verbose("$server_name $channel $nick($hostmask): $what");

	foreach my $h (@{get_hooks($HOOK_PUBLIC)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$where";
			$args{'Message'} = "$what";
			&$h(\%args);
		}
	}
}

# nick in use
sub irc_433 {
	my ($kernel,$sender) = @_[KERNEL,SENDER];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	$kernel->post( $sender => nick => $NICKNAME.$$ );

	foreach my $h (@{get_hooks($HOOK_NICK_IN_USE)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			&$h(\%args);
		}
	}

}

sub irc_ctcp_action {
	my ( $kernel, $sender, $who, $where, $what ) = @_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my $nick     = ( split /!/, $who )[0];
	my $hostmask = ( split /!/, $who )[1];
	my $channel  = $where->[0];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	verbose("$where $nick($hostmask) $what");

	foreach my $h (@{get_hooks($HOOK_ACTION)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$channel";
			$args{'Action'} = "$what";
			&$h(\%args);
		}
	}

}

sub irc_topic {
	my ( $kernel, $sender, $who, $where, $what, $old ) =
		@_[ KERNEL, SENDER, ARG0, ARG1, ARG2, ARG3 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $old_topic = $old->{Value};
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	verbose("$where topic set to \"$what\" by $nick($hostmask)");

	foreach my $h (@{get_hooks($HOOK_TOPIC)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$where";
			$args{'Topic'} = "$what";
			$args{'Old'} = "$old";
			&$h(\%args);
		}
	}

}

sub irc_invite {
	my ( $kernel, $sender, $who, $where ) =
		@_[ KERNEL, SENDER, ARG0, ARG1 ];

	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	verbose("$nick($hostmask) invited me to $where");

	foreach my $h (@{get_hooks($HOOK_INVITE)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$where";
			&$h(\%args);
		}

	}
}

sub irc_kick {
	my ( $kernel, $sender, $who, $where, $target, $why, $targetfull ) =
		@_[ KERNEL, SENDER, ARG0, ARG1, ARG2, ARG3, ARG4 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $target_nick    = ( split /!/, $targetfull )[0];
	my $target_hostmask    = ( split /!/, $targetfull )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	if($why ne ''){
		verbose("$nick($hostmask) kicked $target from $where ($why)");
	} else {
		verbose("$nick($hostmask) kicked $target from $where");
	}

	foreach my $h (@{get_hooks($HOOK_KICK)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$where";
			$args{'Target'} = "$target_nick";
			$args{'TargetHostmask'} = "$target_hostmask";
			$args{'Reason'} = "$why";
			&$h(\%args);
		}

	}

}

sub irc_mode {
	my ( $kernel, $sender, $who, $target, $mode ) =
		@_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my @ARGS = @_[ ARG3 .. $#_ ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";
	my $arguments = join(' ',@ARGS);

	verbose("$nick($hostmask) set $mode on $target ($arguments)");

	foreach my $h (@{get_hooks($HOOK_MODE)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Target'} = "$target";
			$args{'Mode'} = "$mode";
			$args{'Arguments'} = "$arguments";
			&$h(\%args);
		}

	}

}

sub irc_nick {
	my ( $kernel, $sender, $who, $newnick ) =
		@_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	verbose("$nick($hostmask) changed their nick to $newnick");

	foreach my $h (@{get_hooks($HOOK_NICK)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'New'} = "$newnick";
			&$h(\%args);
		}

	}

}

sub irc_notice {
	my ( $kernel, $sender, $who, $targets, $what ) =
		@_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";
	my $t = join(',',@{$targets});

	verbose("$nick($hostmask) sent a notice to $t: $what");

	foreach my $h (@{get_hooks($HOOK_NOTICE)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Targets'} = \@{$targets};
			$args{'Message'} = "$what";
			&$h(\%args);
		}

	}

}

sub irc_raw {
	my ( $kernel, $sender, $raw ) =
		@_[ KERNEL, SENDER, ARG0 ];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	foreach my $h (@{get_hooks($HOOK_RAW)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Line'} = "$raw";
			&$h(\%args);
		}

	}

}

sub irc_raw_out {
	my ( $kernel, $sender, $raw ) =
		@_[ KERNEL, SENDER, ARG0 ];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	foreach my $h (@{get_hooks($HOOK_RAW_OUT)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'ServerID'} = "$irc->{server}:$irc->{port}";
			$args{'Line'} = "$raw";
			&$h(\%args);
		}

	}

}

# DCC EVENTS

sub irc_dcc_request {
	my ($kernel, $sender, $heap, $who, $type, $port, $cookie, $filename, $size, $ip) =
		@_[KERNEL, SENDER, HEAP, ARG0 .. ARG6];
	if(!$ENABLE_DCC){ return undef; }
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	

	#if($type eq 'CHAT'){ $kernel->post( $sender => dcc_accept => $cookie ); }


	if($type eq 'CHAT'){
		foreach my $h (@{get_hooks($HOOK_DCC_CHAT_REQUEST)}){
			if(ref($h) eq 'CODE'){
				my %args;
				$args{'ServerID'} = "$irc->{server}:$irc->{port}";
				$args{'Nickname'} = "$nick";
				$args{'Hostmask'} = "$hostmask";
				$args{'IP'} = "$ip";
				$args{'Port'} = "$port";
				$args{'Cookie'} = "$cookie";
				my $ret = &$h(\%args);
				if($ret){
					# request accepted
					$kernel->post( $sender => dcc_accept => $cookie );
				} else {
					# request denied.
					$kernel->post( $sender => dcc_close => $cookie );
				}
			}
		}
	}

	if($type eq 'SEND'){
		foreach my $h (@{get_hooks($HOOK_DCC_SEND_REQUEST)}){
			if(ref($h) eq 'CODE'){
				my %args;
				$args{'ServerID'} = "$irc->{server}:$irc->{port}";
				$args{'Nickname'} = "$nick";
				$args{'Hostmask'} = "$hostmask";
				$args{'IP'} = "$ip";
				$args{'Port'} = "$port";
				$args{'Cookie'} = "$cookie";
				$args{'File'} = "$filename";
				$args{'Size'} = "$size";
				my $ret = &$h(\%args);
				if($ret){
					# request accepted
					my $df = File::Spec->catfile($FILE_DIRECTORY,$filename);
					$kernel->post( $sender => dcc_accept => $cookie => $df );
				} else {
					# request denied.
					$kernel->post( $sender => dcc_close => $cookie );
				}
			}
		}
	}


}

sub irc_dcc_start {
	my ($kernel, $sender, $heap, $cookie, $nick, $type, $port, $ip) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2, ARG3, ARG6];
	if(!$ENABLE_DCC){ return undef; }
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	foreach my $h (@{get_hooks($HOOK_DCC_START)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'Nickname'} = "$nick";
			$args{'IP'} = "$ip";
			$args{'Port'} = "$port";
			$args{'Cookie'} = "$cookie";
			$args{'Type'} = "$type";
			&$h(\%args);
		}
	}

}

sub irc_dcc_chat {
	my ($kernel, $sender, $heap, $cookie, $nick, $port, $line, $ip) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2, ARG3, ARG4];
	if(!$ENABLE_DCC){ return undef; }
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	foreach my $h (@{get_hooks($HOOK_DCC_INCOMING)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'Nickname'} = "$nick";
			$args{'IP'} = "$ip";
			$args{'Port'} = "$port";
			$args{'Message'} = "$line";
			$args{'Cookie'} = "$cookie";
			&$h(\%args);
		}
	}

}

sub irc_dcc_done {
	my ($kernel, $sender, $heap, $cookie, $nick, $type, $port, $ip) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2, ARG3, ARG7];
	if(!$ENABLE_DCC){ return undef; }
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	foreach my $h (@{get_hooks($HOOK_DCC_DONE)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'Nickname'} = "$nick";
			$args{'IP'} = "$ip";
			$args{'Port'} = "$port";
			$args{'Type'} = "$type";
			$args{'Cookie'} = "$cookie";
			&$h(\%args);
		}
	}

}

sub irc_dcc_error {
	my ($kernel, $sender, $heap, $cookie, $err, $nick, $type, $port, $ip) =
		@_[KERNEL, SENDER, HEAP, ARG0 .. ARG4, ARG8];
	if(!$ENABLE_DCC){ return undef; }
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	foreach my $h (@{get_hooks($HOOK_DCC_ERROR)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'Nickname'} = "$nick";
			$args{'IP'} = "$ip";
			$args{'Port'} = "$port";
			$args{'Type'} = "$type";
			$args{'Cookie'} = "$cookie";
			$args{'Error'} = "$err";
			&$h(\%args);
		}
	}

}

# receive file
sub irc_dcc_get {
	my ($kernel, $sender, $heap, $cookie, $nick, $port, $file, $size, $transferred_size, $ip) =
		@_[KERNEL, SENDER, HEAP, ARG0 .. ARG6];
	if(!$ENABLE_DCC){ return undef; }
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	foreach my $h (@{get_hooks($HOOK_DCC_GET)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'Nickname'} = "$nick";
			$args{'IP'} = "$ip";
			$args{'Port'} = "$port";
			$args{'Cookie'} = "$cookie";
			$args{'File'} = "$file";
			$args{'Size'} = "$size";
			$args{'Transferred'} = "$transferred_size";
			&$h(\%args);
		}
	}

}

# send file
sub irc_dcc_send {
	my ($kernel, $sender, $heap, $cookie, $nick, $port, $file, $size, $transferred_size, $ip) =
		@_[KERNEL, SENDER, HEAP, ARG0 .. ARG6];
	if(!$ENABLE_DCC){ return undef; }
	my $irc = $sender->get_heap();
	my $server_name = $irc->server_name();
	my $server_host = $irc->{server};
	my $server_port = $irc->{port};
	my $alias = "$server_host:$server_port";

	foreach my $h (@{get_hooks($HOOK_DCC_GET)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'Nickname'} = "$nick";
			$args{'IP'} = "$ip";
			$args{'Port'} = "$port";
			$args{'Cookie'} = "$cookie";
			$args{'File'} = "$file";
			$args{'Size'} = "$size";
			$args{'Transferred'} = "$transferred_size";
			&$h(\%args);
		}
	}

}

# ==================================
# | POE::COMPONENT::IRC EVENTS END |
# ==================================

# =============================
# | SUPPORT SUBROUTINES BEGIN |
# =============================

# delay_function()
# Arguments: 2 (time to delay in seconds,function reference)
# Returns: Nothing
# Description: Adds a function to the delay list.
sub delay_function {
	my $time = shift;
	my $func = shift;

	my @e = ($UPTIME+$time,$func);
	push(@DELAY,\@e);
}

# create_javascript_context()
# Arguments: None
# Returns: JavaScript::V8::Context object
# Description: Creates a JS::V8 context and returns it.
sub create_javascript_context {
	my $js = JavaScript::V8::Context->new();
	$js = add_basic_libretto_functions($js);
	$js = add_server_libretto_functions($js);
	$js = add_irc_libretto_functions($js);
	$js = add_miscellaneous_libretto_functions($js);
	$js = add_event_libretto_functions($js);
	$js = add_httpd_libretto_functions($js);
	$js = add_irc_server_libretto_functions($js);
	$js = add_file_io_libretto_functions($js);
	$js = add_zip_libretto_functions($js);

	return $js;
}


sub get_from_serverpile {
	my $port = shift;
	foreach my $e (@SERVERPILE){
		my @ea = @{$e};
		if($ea[0] eq $port){ return $ea[1]; }
	}
	return undef;
}

sub add_zip_libretto_functions {
	my $js = shift;

	$js->bind_function( "$FUNCTION_REMOVE_ZIP_MEMBER" => sub {
        if ( scalar @_ == 2 ) {
            if(is_valid_zip($_[0])){
            	my @a = @{get_zip($_[0])};
            	$a[ZIP_FILE]->removeMember($_[1]);
            	return 1;
        	} else {
        		display_warning("No zip file with ID \"$_[0]\" exists");
            	return 0;
        	}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_REMOVE_ZIP_MEMBER\" (2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_EXTRACT_ZIP" => sub {
        if ( scalar @_ == 2 ) {
            if(is_valid_zip($_[0])){
            	my @a = @{get_zip($_[0])};
            	$a[ZIP_FILE]->extractTree(undef, $_[1]);
            	return 1;
        	} else {
        		display_warning("No zip file with ID \"$_[0]\" exists");
            	return 0;
        	}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_EXTRACT_ZIP\" (2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_GET_ZIP_MEMBER" => sub {
        if ( scalar @_ == 2 ) {
            if(is_valid_zip($_[0])){
            	my @a = @{get_zip($_[0])};
            	my $c = $a[ZIP_FILE]->contents($_[1]);
            	if($c){ return $c; } else {
            		display_warning("Zip file member \"$_[0]\" is empty or doesn't exist");
            		return undef;
            	}
            	return undef;
        	} else {
        		display_warning("No zip file with ID \"$_[0]\" exists");
            	return 0;
        	}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_GET_ZIP_MEMBER\" (2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_LIST_ZIP_MEMBERS" => sub {
        if ( scalar @_ == 1 ) {
            if(is_valid_zip($_[0])){
            	my @a = @{get_zip($_[0])};
            	my @l = $a[ZIP_FILE]->memberNames();
            	return \@l;
        	} else {
        		display_warning("No zip file with ID \"$_[0]\" exists");
            	return 0;
        	}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_LIST_ZIP_MEMBERS\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_ADD_TO_ZIP" => sub {
        if ( scalar @_ == 2 ) {
            if(is_valid_zip($_[0])){
            	my @a = @{get_zip($_[0])};
            	if(-e $_[1]){
            		if(-f $_[1]){
	            		$a[ZIP_FILE]->addFile($_[1]);
	            		return 1;
	            	} elsif(-d $_[1]){
            			$a[ZIP_FILE]->addTree($_[1],basename($_[1]));
            			return 1;
            		} else {
        				display_warning("\"$_[1]\" is not a file or directory");
        				return 0;
            		}
            		return 1;
            	} else {
            		display_warning("File or directory \"$_[1]\" doesn't exist");
            		return 0;
            	}
        	} else {
        		display_warning("No zip file with ID \"$_[0]\" exists");
            	return 0;
        	}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_ADD_TO_ZIP\" (2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_SAVE_ZIP" => sub {
        if ( scalar @_ == 1 ) {
            if(is_valid_zip($_[0])){
            	my @a = @{get_zip($_[0])};
            	if((-e $a[ZIP_FILE_NAME])&&(-f $a[ZIP_FILE_NAME])){
            		if ($a[ZIP_FILE]->overwrite($a[ZIP_FILE_NAME]) != AZ_OK) {  # write to disk
					    display_warning("Error overwriting zip file \"$a[ZIP_FILE_NAME]\"");
					    return 0;
					} else {
						return 1;
					}
            	} else {
	            	if ($a[ZIP_FILE]->writeToFileNamed($a[ZIP_FILE_NAME]) != AZ_OK) {  # write to disk
	            		display_warning("Error creating zip file \"$a[ZIP_FILE_NAME]\"");
					    return 0;
					} else {
						return 1;
					}
				}
        	} else {
        		display_warning("No zip file with ID \"$_[0]\" exists");
            	return 0;
        	}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_SAVE_ZIP\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_NEW_ZIP" => sub {
        if ( scalar @_ == 1 ) {
        	return create_new_zip($_[0]);
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_NEW_ZIP\" (1 required, ".(scalar @_)." passed)");
        }
    });

    $js->bind_function( "$FUNCTION_CLOSE_ZIP" => sub {
        if ( scalar @_ == 1 ) {
            if(is_valid_zip($_[0])){
            	remove_zip($_[0]);
            	return 1;
        	} else {
        		display_warning("No zip file with ID \"$_[0]\" exists");
            	return 0;
        	}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_CLOSE_ZIP\" (1 required, ".(scalar @_)." passed)");
        }
    });

	return $js;
}

# add_irc_server_libretto_functions()
# Arguments: 1 (JS::V8::Context object)
# Returns: JavaScript::V8::Context object
# Description: Adds IRCd functions to a JS context.
sub add_irc_server_libretto_functions {
	my $js = shift;

	$js->bind_function( "$FUNCTION_ALL_CHANNELS" => sub {
        if ( scalar @_ == 1 ) {
        	my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		my @nlist = ();
        		foreach my $u ($serv->state_chans()) {
        			push(@nlist,$u);
        		}
        		return \@nlist;
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_ALL_CHANNELS\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_ALL_NICKS" => sub {
        if ( scalar @_ == 1 ) {
        	my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		my @nlist = ();
        		foreach my $u ($serv->state_nicks()) {
        			push(@nlist,$u);
        		}
        		return \@nlist;
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_ALL_NICKS\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_FORCE_KILL" => sub {
        if ( scalar @_ == 2 ) {
        	my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->daemon_server_kill($_[1]);
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
    	} elsif ( scalar @_ == 3 ) {
    		my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->daemon_server_kill($_[1],$_[2]);
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_FORCE_KILL\" (2-3 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_FORCE_KICK" => sub {
        if ( scalar @_ == 3 ) {
        	my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->daemon_server_kick($_[1],$_[2]);
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
    	} elsif ( scalar @_ == 4 ) {
    		my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->daemon_server_kick($_[1],$_[2],$_[3]);
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_FORCE_KICK\" (3-4 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_FORCE_MODE" => sub {
        if ( scalar @_ == 3 ) {
        	my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->daemon_server_mode($_[1],$_[2]);
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_FORCE_MODE\" (3 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_DEL_AUTH" => sub {
        if ( scalar @_ == 2 ) {
        	my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->del_auth( $_[1]);
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_DEL_AUTH\" (2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_ADD_AUTH" => sub {
        if ( scalar @_ == 2 ) {
        	my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->add_auth(
			        {
			            mask	=> $_[1],
			        }
			    );
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
    	} elsif ( scalar @_ == 3 ) {
    		my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->add_auth(
			        {
			            mask		=> $_[1],
			            password	=> $_[2],
			        }
			    );
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
    	} elsif ( scalar @_ == 4 ) {
    		my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->add_auth(
			        {
			            mask		=> $_[1],
			            password	=> $_[2],
			            spoof		=> $_[3],
			        }
			    );
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_ADD_AUTH\" (2-4 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_DEL_OP" => sub {
        if ( scalar @_ == 2 ) {
        	my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->del_operator( $_[1]);
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_DEL_OP\" (2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_ADD_OP" => sub {
        if ( scalar @_ == 3 ) {
        	my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->add_operator(
			        {
			            username	=> $_[1],
			            password	=> $_[2],
			        }
			    );
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
        } elsif (scalar @_ == 4) {
        	my $serv = get_from_serverpile($_[0]);
        	if($serv){
        		$serv->add_operator(
			        {
			            username	=> $_[1],
			            password	=> $_[2],
			            ipmask		=> $_[3],
			        }
			    );
    		} else {
    			display_error("\"$_[0]\" is not a valid host ID");
    		}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_ADD_OP\" (3-4 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_SERVER" => sub {
        if ( scalar @_ == 1 ) {
        	if(ref($_[0]) eq 'HASH'){
        		spawn_new_irc_server($_[0]);
        	} else {
        		display_error("Connection failed; \"$_[0]\" is not an object");
        	}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_SERVER\" (1 required, ".(scalar @_)." passed)");
        }
    });

	return $js;
}

# add_httpd_libretto_functions()
# Arguments: 1 (JS::V8::Context object)
# Returns: JavaScript::V8::Context object
# Description: Adds HTTPD functions to a JS context.
sub add_httpd_libretto_functions {
	my $js = shift;

	$js->bind_function( "$FUNCTION_WEBHOOK" => sub {
        if ( scalar @_ == 3 ) {
        	if($HTTPD_AVAILABLE){}else{ return 0; }
        	if(ref($_[2]) eq 'CODE'){}else{
        		display_error("Webhook failed: \"$_[1]\" is not a function reference");
        	}
            create_web_server("$_[1]","$_[0]",$_[2]);
            return 1;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_WEBHOOK\" (3 required, ".(scalar @_)." passed)");
        }
    });

	return $js;
}

# add_event_libretto_functions()
# Arguments: 1 (JS::V8::Context object)
# Returns: JavaScript::V8::Context object
# Description: Adds event functions to a JS context.
sub add_event_libretto_functions {
	my $js = shift;

	$js->bind_function( "$FUNCTION_DELAY" => sub {
        if ( scalar @_ == 2 ) {
        	if(ref($_[1]) eq 'CODE'){}else{
        		display_error("Delay failed: \"$_[1]\" is not a function reference");
        	}
            delay_function($_[0],$_[1]);
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_DELAY\" (2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_UNHOOK" => sub {
        if ( scalar @_ == 1 ) {
            remove_hook($_[0]);
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_UNHOOK\" (1 required, ".(scalar @_)." passed)");
        }
    });

 	$js->bind_function( "$FUNCTION_HOOK" => sub {
        if ( scalar @_ == 3 ) {
        	if(ref($_[2]) eq 'CODE'){}else{
        		display_error("Hook $_[0], $_[1] failed: \"$_[2]\" is not a function reference");
        	}
            add_hook($_[0],$_[1],$_[2]);
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_HOOK\" (3 required, ".(scalar @_)." passed)");
        }
    });

	return $js;
}

# add_miscellaneous_libretto_functions()
# Arguments: 1 (JS::V8::Context object)
# Returns: JavaScript::V8::Context object
# Description: Adds miscellaneous functions to a JS context.
sub add_miscellaneous_libretto_functions {
	my $js = shift;

	$js->bind_function( "$FUNCTION_SHUTDOWN" => sub {
        if ( scalar @_ == 1 ) {
           shutdown_alias($_[0]);
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_SHUTDOWN\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_TOKENS" => sub {
        if ( scalar @_ == 1 ) {
           my @q = shellwords($_[0]);
           return \@q;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_TOKENS\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_EXEC" => sub {
        if ( scalar @_ == 1 ) {
           my $r = `$_[1]`;
           chomp $r;
           return $r;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_EXEC\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_INCLUDE" => sub {
        if ( scalar @_ >= 1 ) {
        	foreach my $f (@_){
        		$f = search_for_use_file($f);
        		if($f){
        			open(FILE,"<$f") or display_error("include() error; error reading file \"$f\"");
        			my $s = join('',<FILE>);
        			close FILE;
        			execute_javascript($s);
        		} else {
        			display_error("use() error; file \"$f\" not found");
        		}
        	}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_INCLUDE\" (1+ required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_EXIT" => sub {
        if ( scalar @_ == 0 ) {
        	$js->exit_throws_a_segfault_so_this_is_how_we_exit_without_throwing_a_segfault_zero();
        }elsif ( scalar @_ == 1 ) {
        	if($_[0]==0){
        		$js->exit_throws_a_segfault_so_this_is_how_we_exit_without_throwing_a_segfault_zero();
        	} elsif($_[0]==1){
        		$js->exit_throws_a_segfault_so_this_is_how_we_exit_without_throwing_a_segfault_one();
    		} else {
    			display_warning("exit() must be passed no argument, \"0\", or \"1\"; \"$_[0]\" passed");
    			$js->exit_throws_a_segfault_so_this_is_how_we_exit_without_throwing_a_segfault_zero();
    		}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_EXIT\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_SHA_512" => sub {
        if ( scalar @_ == 1 ) {
           return sha512_base64($_[0]);
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_SHA_512\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_SHA_256" => sub {
        if ( scalar @_ == 1 ) {
           return sha256_base64($_[0]);
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_SHA_256\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_DECODE_BASE64" => sub {
        if ( scalar @_ == 1 ) {
           my $s = decode_base64($_[0]);
           return $s;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_DECODE_BASE64\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_ENCODE_BASE64" => sub {
        if ( scalar @_ == 1 ) {
           my $s = encode_base64($_[0]);
           return $s;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_ENCODE_BASE64\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_TIMESTAMP" => sub {
        if ( scalar @_ == 0 ) {
			return timestamp();
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_TIMESTAMP\" (0 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_TERMCOLOR" => sub {
        if ( scalar @_ == 2 ) {
			if(colorvalid($_[0])){
				return colored($_[1], $_[0]);
			} else {
				display_warning("\"$_[0]\" is not a valid color");
				return $_[0];
			}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_TERMCOLOR\" (2 required, ".(scalar @_)." passed)");
        }
    });

	return $js;
}

sub get_from_pile {
	my $alias = shift;
	foreach my $e (@PILE){
		my @ea = @{$e};
		if($ea[0] eq $alias){ return $ea[1]; }
	}
	return undef;
}

# add_irc_libretto_functions()
# Arguments: 1 (JS::V8::Context object)
# Returns: JavaScript::V8::Context object
# Description: Adds IRC related functions
sub add_irc_libretto_functions {
	my $js = shift;

	$js->bind_function( "$FUNCTION_RECONNECT" => sub {
        if ( scalar @_ == 1 ) {
           my $irc = get_from_pile($_[0]);
           $irc->yield( connect => { } );
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_RECONNECT\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_DCC_SEND" => sub {
        if ( scalar @_ == 3 ) {
        	my $irc = get_from_pile($_[0]);
        	if((-e $_[2])&&(-f $_[2])){
        		$irc->yield( 'dcc' => "$_[1]" => SEND => $_[2] );
			} else {
				display_error("Can't DCC send file \"$_[2]\" (file not found)");
			}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_DCC_SEND\" (3 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_SET_MODE" => sub {
        if ( scalar @_ == 2) {
        	my $irc = get_from_pile($_[0]);
			$irc->yield( 'mode' => "$_[1]" );
		} else {
            display_error("Wrong number of arguments to \"$FUNCTION_SET_MODE\" (2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_NOTICE" => sub {
        if ( scalar @_ == 3) {
        	my $irc = get_from_pile($_[0]);
			$irc->yield( 'notice' => "$_[1]" => "$_[2]" );
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_NOTICE\" (3 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_INVITE" => sub {
        if ( scalar @_ == 3) {
        	my $irc = get_from_pile($_[0]);
			$irc->yield( 'invite' => "$_[1]" => "$_[2]" );
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_INVITE\" (3 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_RAW" => sub {
		if(scalar @_ == 2){
			my $irc = get_from_pile($_[0]);
			$irc->yield( 'quote' => "$_[1]" );
		} else {
			display_error("Wrong number of arguments to \"$FUNCTION_RAW\" (2 required, ".(scalar @_)." passed)");
		}
    });

	$js->bind_function( "$FUNCTION_WHOIS" => sub {
		if(scalar @_ == 2){
			my $irc = get_from_pile($_[0]);
			my $x = $irc->nick_info($_[1]);
			if($x){
				return \%{$x};
			} else {
				return undef;
			}
		} else {
			display_error("Wrong number of arguments to \"$FUNCTION_WHOIS\" (2 required, ".(scalar @_)." passed)");
		}
    });

	# BEGIN CHANNEL

	# array = channel(server,"list");
	# array = channel(server,channel,"users")
	# key = channel(server,channel,"key")
	# topic = channel(server,channel,"topic")
	$js->bind_function( "$FUNCTION_CHANNEL" => sub {
		if(scalar @_ == 2){
			if(lc($_[1]) eq 'list'){
				my $irc = get_from_pile($_[0]);
				my @l = ();
				for my $channel ( keys %{ $irc->channels() } ) {
				    push(@l,$channel);
				}
				return \@l;
			} else {
				display_error("Unrecognized argument to \"$FUNCTION_CHANNEL\": \"$_[1]\"");
			}
		} elsif(scalar @_ == 3){

			if(lc($_[2]) eq 'users'){
				my $irc = get_from_pile($_[0]);
				my @l = $irc->channel_list($_[1]);
				return \@l;
			} elsif(lc($_[2]) eq 'key'){
				my $irc = get_from_pile($_[0]);
				return $irc->channel_key($_[1]);
			} elsif(lc($_[2]) eq 'topic'){
				my $irc = get_from_pile($_[0]);
				my $t = $irc->channel_topic($_[1]);
				return $t->{Value};
			} elsif(lc($_[2]) eq 'ops'){
				my $irc = get_from_pile($_[0]);
				my @l = $irc->channel_list($_[1]);
				my @o = ();
				foreach my $u (@l){
					if($irc->is_channel_operator($_[1],$u)){
						push(@o,$u);
					}
				}
				return \@o;
			} elsif(lc($_[2]) eq 'admins'){
				my $irc = get_from_pile($_[0]);
				my @l = $irc->channel_list($_[1]);
				my @o = ();
				foreach my $u (@l){
					if($irc->is_channel_admin($_[1],$u)){
						push(@o,$u);
					}
				}
				return \@o;
			} elsif(lc($_[2]) eq 'halfops'){
				my $irc = get_from_pile($_[0]);
				my @l = $irc->channel_list($_[1]);
				my @o = ();
				foreach my $u (@l){
					if($irc->is_channel_halfop($_[1],$u)){
						push(@o,$u);
					}
				}
				return \@o;
			} elsif(lc($_[2]) eq 'voiced'){
				my $irc = get_from_pile($_[0]);
				my @l = $irc->channel_list($_[1]);
				my @o = ();
				foreach my $u (@l){
					if($irc->has_channel_voice($_[1],$u)){
						push(@o,$u);
					}
				}
				return \@o;
			} else{
				display_error("Unrecognized argument to \"$FUNCTION_CHANNEL\": \"$_[2]\"");
			}
		} else {
			display_error("Wrong number of arguments to \"$FUNCTION_CHANNEL\" (2-3 required, ".(scalar @_)." passed)");
		}
    });

	# END CHANNEL

	$js->bind_function( "$FUNCTION_NICK" => sub {
		if(scalar @_ == 2){
			my $irc = get_from_pile($_[0]);
			$irc->yield( 'nick' => "$_[1]" );
		} else {
			display_error("Wrong number of arguments to \"$FUNCTION_NICK\" (2 required, ".(scalar @_)." passed)");
		}
    });

	$js->bind_function( "$FUNCTION_TOPIC" => sub {
		if(scalar @_ == 3){
			my $irc = get_from_pile($_[0]);
			$irc->yield( 'topic' => "$_[1]" => "$_[2]" );
		} else {
			display_error("Wrong number of arguments to \"$FUNCTION_TOPIC\" (3 required, ".(scalar @_)." passed)");
		}
    });

	$js->bind_function( "$FUNCTION_MESSAGE" => sub {
		if(scalar @_ == 3){
			my $irc = get_from_pile($_[0]);
			$irc->yield( 'privmsg' => "$_[1]" => "$_[2]" );
		} else {
			display_error("Wrong number of arguments to \"$FUNCTION_MESSAGE\" (3 required, ".(scalar @_)." passed)");
		}
    });

	$js->bind_function( "$FUNCTION_COLOR" => sub {
        if ( scalar @_ == 3 ) {
            return $COLOR_TEXT.$_[0].",".$_[1].$_[2].$COLOR_TEXT;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_COLOR\" (3 required, ".(scalar @_)." passed)");
        }
    });

    $js->bind_function( "$FUNCTION_ITALIC" => sub {
        if ( scalar @_ == 1 ) {
            return $ITALIC_TEXT.$_[0].$ITALIC_TEXT;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_ITALIC\" (1 required, ".(scalar @_)." passed)");
        }
    });

    $js->bind_function( "$FUNCTION_UNDERLINE" => sub {
        if ( scalar @_ == 1 ) {
            return $UNDERLINE_TEXT.$_[0].$UNDERLINE_TEXT;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_UNDERLINE\" (1 required, ".(scalar @_)." passed)");
        }
    });


    $js->bind_function( "$FUNCTION_BOLD" => sub {
        if ( scalar @_ == 1 ) {
            return $BOLD_TEXT.$_[0].$BOLD_TEXT;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_BOLD\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_PART" => sub {
        if ( scalar @_ == 2 ) {
        	my $irc = get_from_pile($_[0]);
			$irc->yield( 'part' => "$_[1]" );
        } elsif ( scalar @_ == 3 ) {
        	my $irc = get_from_pile($_[0]);
			$irc->yield( 'part' => "$_[1]" => "$_[0]" );
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_PART\" (2-3 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_JOIN" => sub {
        if ( scalar @_ == 2 ) {
        	my $irc = get_from_pile($_[0]);
			$irc->yield( 'join' => "$_[1]" );
        } elsif ( scalar @_ == 3 ) {
        	my $irc = get_from_pile($_[0]);
			$irc->yield( 'join' => "$_[1]" => "$_[2]" );
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_JOIN\" (2-3 required, ".(scalar @_)." passed)");
        }
    });

    $js->bind_function( "$FUNCTION_DCC_CHAT" => sub {
        if ( scalar @_ == 3 ) {
        	my $irc = get_from_pile($_[0]);
            $irc->yield( 'dcc_chat' => $_[1] => $_[2] );
        } else {
            kronos_error("Wrong number of arguments to \"$FUNCTION_DCC_CHAT\" (3 required, ".(scalar @_)." passed)");
        }
    });

    $js->bind_function( "$FUNCTION_DCC_CLOSE" => sub {
        if ( scalar @_ == 2) {
        	my $irc = get_from_pile($_[0]);
        	$irc->yield( dcc_close => $_[1] );
        } else {
            kronos_error("Wrong number of arguments to \"$FUNCTION_DCC_CLOSE\" (2 required, ".(scalar @_)." passed)");
        }
    });

	return $js;
}

# add_server_libretto_functions()
# Arguments: 1 (JS::V8::Context object)
# Returns: JavaScript::V8::Context object
# Description: Adds the connect() and disconnect() functions
sub add_server_libretto_functions {
	my $js = shift;

	$js->bind_function( "$FUNCTION_DISCONNECT" => sub {
        if ( scalar @_ == 1 ) {
        	$KERNEL->post( "$_[0]" => 'quit' );
        } elsif ( scalar @_ == 2 ) {
        	$KERNEL->post( "$_[0]" => 'quit' => "$_[1]" );
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_DISCONNECT\" (1-2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_CONNECT" => sub {
        if ( scalar @_ == 1 ) {
        	if(ref($_[0]) eq 'HASH'){
        		my $r = execute_javascript("$FUNCTION_CONNECT.caller;");
        		if($r){
        			display_error("connect() should only be called in the global scope");
        		}
        		spawn_new_client_connection($_[0]);
        	} else {
				display_error("Connection failed; \"$_[0]\" is not an object");
			}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_CONNECT\" (1 required, ".(scalar @_)." passed)");
        }
    });

	return $js;
}

# add_basic_libretto_functions()
# Arguments: 1 (JS::V8::Context object)
# Returns: JavaScript::V8::Context object
# Description: Adds the print(), verbose(), and warn() functions to
#              the Javascript engine.
sub add_basic_libretto_functions {
	my $js = shift;

	$js->bind_function( "$FUNCTION_PRINT" => sub {
        foreach my $e (@_){
        	print "$e\n";
        }
    });

    $js->bind_function( "$FUNCTION_VERBOSE" => sub {
    	if($VERBOSE){
	        foreach my $e (@_){
	        	print "$e\n";
	        }
	    }
    });

    $js->bind_function( "$FUNCTION_WARN" => sub {
    	if($WARN){
	        foreach my $e (@_){
	        	print "$e\n";
	        }
	    }
    });

	return $js;
}

sub add_file_io_libretto_functions {
	my $js = shift;

	$js->bind_function( "$FUNCTION_TEMPDIR" => sub {
        if ( scalar @_ == 0 ) {
			my $td = File::Spec->tmpdir();
			if((-r $td)&&(-w $td)){
				return $td;
			} else {
				return undef;
			}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_TEMPDIR\" (0 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_CATFILE" => sub {
        if ( scalar @_ >= 1 ) {
           my @dirs = ();
           foreach my $e (@_){
           		if(ref($e) eq 'ARRAY'){
           			foreach my $ea (@{$e}){
           				push(@dirs,$ea);
           			}
           		} else {
           			push(@dirs,$e);
           		}
           }
           return File::Spec->catfile( @dirs );
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_CATFILE\" (1+ required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_CATDIR" => sub {
        if ( scalar @_ >= 1 ) {
           my @dirs = ();
           foreach my $e (@_){
           		if(ref($e) eq 'ARRAY'){
           			foreach my $ea (@{$e}){
           				push(@dirs,$ea);
           			}
           		} else {
           			push(@dirs,$e);
           		}
           }
           return File::Spec->catdir( @dirs );
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_CATDIR\" (1+ required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_CHANGE_DIRECTORY" => sub {
        if ( scalar @_ == 1 ) {
           chdir($_[0]) or return 0;
           return 1;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_CHANGE_DIRECTORY\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_FILE_LOCATION" => sub {
        if ( scalar @_ == 1 ) {
           my($filename, $dirs, $suffix) = fileparse($_[0]);
           return $dirs;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_FILE_LOCATION\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_FILE_BASENAME" => sub {
        if ( scalar @_ == 1 ) {
           my($filename, $dirs, $suffix) = fileparse($_[0]);
           return $filename;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_FILE_BASENAME\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_FILE_PERMISSIONS" => sub {
        if ( scalar @_ == 1 ) {
        	if((-e $_[0])&&(-f $_[0])){
				my $p = '';
				if(-r $_[0]){ $p .= 'r'; }
				if(-w $_[0]){ $p .= 'w'; }
				if(-x $_[0]){ $p .= 'x'; }
				return $p;
			} else {
				return '';
			}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_FILE_PERMISSIONS\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_FILE_MODE" => sub {
        if ( scalar @_ == 1 ) {
        	if((-e $_[0])&&(-f $_[0])){
				return (stat($_[0]))[2];
			} else {
				return 0;
			}
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_FILE_MODE\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_CWD" => sub {
        if ( scalar @_ == 0 ) {
          return getcwd();
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_CWD\" (0 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_CHMOD" => sub {
        if ( scalar @_ == 2 ) {
        	chmod($_[0],$_[1]) or return 0;
        	return 1;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_CHMOD\" (2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_FILE_SIZE" => sub {
        if ( scalar @_ == 1 ) {
           my $s = (-s $_[0]);
           return $s;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_FILE_SIZE\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_LIST_DIRECTORY" => sub {
        if ( scalar @_ == 1 ) {
           opendir my $dir, "$_[0]" or display_error("Error opening directory \"$_[0]\" ($!)");
			my @files = readdir $dir;
			closedir $dir;
			return \@files;
        } elsif ( scalar @_ == 2 ) {
        	#my @files = glob( $_[0] . '/'. $_[1] );
        	my @files = glob( File::Spec->catfile($_[0],$_[1]) );
        	my @out = ();
        	foreach my $f (@files){
        		push(@out,basename($f));
        	}
        	return \@out;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_LIST_DIRECTORY\" (1 or 2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_DELETE_FILE" => sub {
        if ( scalar @_ == 1 ) {
           unlink($_[0]) or return 0;
           return 1;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_DELETE_FILE\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_DELETE_PATH" => sub {
        if ( scalar @_ == 1 ) {
           remove_tree($_[0]) or return 0;
           return 1;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_DELETE_PATH\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_DELETE_DIRECTORY" => sub {
        if ( scalar @_ == 1 ) {
           rmdir($_[0]) or return 0;
           return 1;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_DELETE_DIRECTORY\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_MAKE_PATH" => sub {
        if ( scalar @_ == 1 ) {
           make_path($_[0]) or return 0;
           return 1;
        } elsif ( scalar @_ == 2 ) {
        	make_path($_[0], { chmod => $_[1],}) or return 0;
        	return 1;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_MAKE_PATH\" (1 or 2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_MAKE_DIRECTORY" => sub {
        if ( scalar @_ == 1 ) {
           mkdir($_[0]) or return 0;
           return 1;
        } elsif ( scalar @_ == 2 ) {
        	mkdir($_[0],$_[1]) or return 0;
        	return 1;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_MAKE_DIRECTORY\" (1 or 2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_DIRECTORY_EXISTS" => sub {
        if ( scalar @_ == 1 ) {
           if((-e $_[0])&&(-d $_[0])){ return 1; } else { return 0; }
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_DIRECTORY_EXISTS\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_FILE_EXISTS" => sub {
        if ( scalar @_ == 1 ) {
           if((-e $_[0])&&(-f $_[0])){ return 1; } else { return 0; }
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_FILE_EXISTS\" (1 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_WRITE_FILE" => sub {
        if ( scalar @_ == 2 ) {
           open(FILE,">$_[0]") or kronos_warn("Error opening \"$_[0]\": $!") && return 0;
           print FILE $_[1];
           close FILE;
           return 1;
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_WRITE_FILE\" (2 required, ".(scalar @_)." passed)");
        }
    });

	$js->bind_function( "$FUNCTION_READ_FILE" => sub {
        if ( scalar @_ == 1 ) {
        	if((-e $_[0])&&(-f $_[0])){
	           open(FILE,"<$_[0]") or kronos_warn("Error reading \"$_[0]\": $!") && return undef;
	           my $x = join('',<FILE>);
	           close FILE;
	           return $x;
            } else {
            	return undef;
            }
        } else {
            display_error("Wrong number of arguments to \"$FUNCTION_READ_FILE\" (1 required, ".(scalar @_)." passed)");
        }
    });

	return $js;
}

# execute_javascript()
# Arguments: 1 (JS code)
# Returns: Return value (if any) of the JS code
# Description: Executes JS code in the established JS::V8 context, and
#              returns any return value from that code. If the code has
#              or creates errors, this is displayed.
sub execute_javascript {
	my $code = shift;

	my $ret = $JAVASCRIPT->eval($code);

    if(defined $ret){
        return $ret;
    } else {
        if(defined $@){
            if ( $@ ne '' ) {
            	chomp $@;
                display_error($@);
            }
        }
    }
}

# shutdown_alias()
# Arguments: 1 ( alias)
# Returns: Nothing
# Description: Shuts the process with the given alias down.
sub shutdown_alias {
	my $alias = shift;

	my @c = ();
	my $f = undef;
	foreach my $w (@WEBPILE){
		if($w eq $alias){
			$poe_kernel->post( $alias => 'shutdown');
			$f = 1;
			next;
		}
		push(@c,$w);
	}
	@WEBPILE = @c;
	if($f){}else{
		display_warning("Webhook \"$alias\" not found");
	}
	
}

sub add_to_webpile {
	my $alias = shift;
	push(@WEBPILE,$alias);
}

# create_web_server()
# Arguments: 2 (port number, alias)
# Returns: 1 if successful, undef if not
# Description: Starts a web server on the given port.
sub create_web_server{
	my $port = shift;
	my $alias = shift;
	my $coderef = shift;

	if($HTTPD_AVAILABLE){}else{
		# Service is not available for use
		return undef;
	}

	POE::Component::Server::TCP->new(
		Alias        => $alias,
		Port         => $port,
		ClientFilter => 'POE::Filter::HTTPD',
		ClientInput => sub {
			my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];
		    if ($request->isa("HTTP::Response")) {
		      $heap->{client}->put($request);
		      $kernel->yield("shutdown");
		      return;
		    }
		    # BEGIN RESPONSE
		    # Parse out the resource requested, as well as any
			# "arguments" to the request
			my $httpd_request = $request->uri();
			my($resource,$arguments) = split(quotemeta("?"),$httpd_request);

			# Parse the "arguments" into a hash
			my %args = undef;
			$args{Request} = $resource;
			$args{IP} = $heap->{remote_ip};
			$args{Port} = $heap->{remote_port};
		    if($arguments){
		    	foreach my $a (split('&',$arguments)){
		    		my @p = split('=',$a);
		    		if(scalar @p==2){
		    			$p[0] = uri_unescape($p[0]);
		    			$p[1] = uri_unescape($p[1]);
		    			$args{$p[0]} = $p[1];
		    		}
		    	}
		    }

		    my $content = &$coderef(\%args);

		    if(ref($content) eq 'HASH'){
		    	my %r = %{$content};
		    	if(($r{Code})&&($r{Type})&&($r{Content})){
			    	my $response = HTTP::Response->new($r{Code});
			    	$response->push_header('Content-type', $r{Type});
			    	$response->content($r{Content});
			    	$heap->{client}->put($response);
		   		} else {
		   			my $output = '';
		   			while( my( $key, $val ) = each %r ) {
				        $output .= "$key = $val\n";
				    }
				    my $response = HTTP::Response->new('200');
			    	$response->push_header('Content-type', 'text/plain');
			    	$response->content($output);
			    	$heap->{client}->put($response);
		   		}
	    	} elsif(ref($content) eq ''){
	    		my $response = HTTP::Response->new('200');
		    	$response->push_header('Content-type', 'text/plain');
		    	$response->content($content);
		    	$heap->{client}->put($response);
		    } elsif(ref($content) eq 'ARRAY'){
		    	my @ac = @{$content};
		    	my $response = HTTP::Response->new('200');
		    	$response->push_header('Content-type', 'text/plain');
		    	$response->content(join("\n",@ac));
		    	$heap->{client}->put($response);
	    	} else {
	    		display_error("Webhook \"$alias\" function returned an invalid data type: \"".ref($content).\"");
	    	}
		    # END RESPONSE
		    $kernel->yield("shutdown");
		}
	);

	add_to_webpile($alias);

	return 1;
}

# handle_httpd_request()
# Arguments: 3
# Returns: Nothing
# Description: For use with the HTTPD and SSL HTTPD servers.
sub handle_httpd_request {
	my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

	# Parse out the resource requested, as well as any
	# "arguments" to the request
	my $httpd_request = $request->uri();
	my($resource,$arguments) = split(quotemeta("?"),$httpd_request);

	# Parse the "arguments" into a hash
	my %args = undef;
    if($arguments){
    	foreach my $a (split('&',$arguments)){
    		my @p = split('=',$a);
    		if(scalar @p==2){
    			$p[0] = uri_unescape($p[0]);
    			$p[1] = uri_unescape($p[1]);
    			$args{$p[0]} = $p[1];
    		}
    	}
    }

    # For now, return all the args as a page
    my $output = "<h1>Hello, world!</h1><ul>\n";
	while( my( $key, $val ) = each %args ) {
        $output .= "<li>$key = $val</li>\n";
    }
    $output .= "</ul>\n";
    my $response = HTTP::Response->new('200');
	$response->push_header('Content-type', 'text/html');
	$response->content($output);
	$heap->{client}->put($response);
}

# bytes_to_human_readable()
# Arguments: 1 (number of bytes)
# Returns: String
# Description: Converts bytes to a more readable format (KB, MB, GB, etc).
sub bytes_to_human_readable {
	my $size = shift;
	foreach ('B','KB','MB','GB','TB','PB') {
		return sprintf("%.2f",$size)." $_" if $size < 1024;
		$size /= 1024;
	}
}

# load_configuration_file()
# Arguments: 1 (filename)
# Returns: Nothing
# Description: Loads settings from a file. The settings are general bot settings,
#              not connection related settings. If errors are found, the program
#              will exit after displaying the nature of the errors. This subroutine
#              should be called *BEFORE* spawn_new_client_connection(), as it
#              relies on settings put into place by this subroutine.
sub load_configuration_file {
	my $file = shift;
	my @errors = ();

	if((-e $file)&&(-f $file)){}else{
		push(@errors,"$file: Settings file not found");
	}

	my $xtpp = XML::TreePP->new();
	my $tree = $xtpp->parsefile($file);
	if($tree eq '') { push(@errors,"$file: Settings file is blank"); }

	if($tree->{settings}->{nickname}){
		$NICKNAME = $tree->{settings}->{nickname};
	}

	if($tree->{settings}->{ircname}){
		$IRCNAME = $tree->{settings}->{ircname};
	}

	if($tree->{settings}->{username}){
		$USERNAME = $tree->{settings}->{username};

	if($tree->{settings}->{dcc}->{enable}){
		my $s = $tree->{settings}->{dcc}->{enable};
		if(($s eq '1')||($s eq '0')){
			if($s eq '1'){
				$ENABLE_DCC = 1;
			}
		} else {
			push(@errors,"$file: settings->dcc->enable must be \"0\" (disable) or \"1\" (enable)");
		}
	}
	}

	if($tree->{settings}->{dcc}->{ports}){
		$DCC_PORTS = $tree->{settings}->{dcc}->{ports};
	}

	if($tree->{settings}->{dcc}->{'external-ip'}->{get}){
		my $s = $tree->{settings}->{dcc}->{'external-ip'}->{get};
		if(($s eq '1')||($s eq '0')){
			if($s eq '1'){
				$GET_EXTERNAL_IP_ADDRESS = 1;
			}
		} else {
			push(@errors,"$file: settings->dcc->external-ip->get must be \"0\" (disable) or \"1\" (enable)");
		}
	}

	if($tree->{settings}->{dcc}->{'external-ip'}->{host}){
		$GET_EXTERNAL_IP_ADDRESS_HOST = $tree->{settings}->{dcc}->{'external-ip'}->{host};
	}

	if($tree->{settings}->{dcc}->{'external-ip'}->{set}){
		if($GET_EXTERNAL_IP_ADDRESS){}else{
			if($tree->{settings}->{dcc}->{'external-ip'}->{set} ne ''){
				$EXTERNAL_IP = $tree->{settings}->{dcc}->{'external-ip'}->{set};
			}
		}
	}

	if($tree->{settings}->{verbose}){
		my $s = $tree->{settings}->{verbose};
		if(($s eq '1')||($s eq '0')){
			if($s eq '1'){
				$VERBOSE = 1;
			}
		} else {
			push(@errors,"$file: settings->verbose must be \"0\" (disable) or \"1\" (enable)");
		}
	}

	if($tree->{settings}->{warnings}){
		my $s = $tree->{settings}->{warnings};
		if(($s eq '1')||($s eq '0')){
			if($s eq '1'){
				$WARN = 1;
			}
		} else {
			push(@errors,"$file: settings->warnings must be \"0\" (disable) or \"1\" (enable)");
		}
	}

	if($tree->{settings}->{ipv6}){
		my $s = $tree->{settings}->{ipv6};
		if(($s eq '1')||($s eq '0')){
			if($s eq '1'){
				$USE_IPV6 = 1;
			}
		} else {
			push(@errors,"$file: settings->ipv6 must be \"0\" (disable) or \"1\" (enable)");
		}
	}

	if($tree->{settings}->{'flood-protection'}){
		my $s = $tree->{settings}->{'flood-protection'};
		if(($s eq '1')||($s eq '0')){
			if($s eq '0'){
				$NO_FLOOD_PROTECTION = 1;
			}
		} else {
			push(@errors,"$file: settings->flood-protection must be \"0\" (disable) or \"1\" (enable)");
		}
	}

	# Colors

	if($tree->{settings}->{color}->{enable}){
		my $s = $tree->{settings}->{color}->{enable};
		if(($s eq '1')||($s eq '0')){
			if($s eq '1'){
				$USE_TERM_COLORS = 1;
			}
		} else {
			push(@errors,"$file: settings->color->enable must be \"0\" (disable) or \"1\" (enable)");
		}
	}

	if($tree->{settings}->{color}->{verbose}){
		if($USE_TERM_COLORS){
			$VERBOSE_COLOR = $tree->{settings}->{color}->{verbose};
		}
	}

	if($tree->{settings}->{color}->{warnings}){
		if($USE_TERM_COLORS){
			$WARN_COLOR = $tree->{settings}->{color}->{warnings};
		}
	}

	if($tree->{settings}->{color}->{errors}){
		if($USE_TERM_COLORS){
			$ERROR_COLOR = $tree->{settings}->{color}->{errors};
		}
	}

	# Error checking

	if($NICKNAME){}else{
		push(@errors,"$file: Nickname not found");
	}

	my @p = parse_dcc_port_list($DCC_PORTS);
	if(scalar @p >= 1){
		@USE_DCC_PORTS = @p;
	}else{
		push(@errors,"$file: DCC port list entry malformed");
	}

	if(scalar @errors >=1){
		display_error(@errors);
	}

	return undef;
}

# spawn_new_client_connection()
# Arguments: 1 (filename)
# Returns: Nothing
# Description: Loads server configuration settings from an XML file, and spawns a
#              POE::Component::IRC setup from those settings. If errors are found
#              in the configuration file, the program will exit after displaying
#              the nature of the errors. load_configuration_file() should be called
#              *BEFORE* this subroutine is called, as it relies on settings put in
#              place by that subroutine.
sub spawn_new_client_connection {
	my $tree = shift;
	my @errors = ();

	my $SERVER_ADDRESS   		= undef;
	my $SERVER_PORT				= undef;
	my $SERVER_PASSWORD			= undef;
	my $USE_PROXY				= undef;
	my $PROXY_SERVER			= undef;
	my $PROXY_PORT				= undef;
	my $USE_SOCKS				= undef;
	my $SOCKS_SERVER			= undef;
	my $SOCKS_PORT				= undef;
	my $SOCKS_ID				= undef;
	my $USE_SSL					= undef;
	my $SSL_KEY					= undef;
	my $SSL_CERT				= undef;

	if($tree->{nickname}){
		$NICKNAME = $tree->{nickname};
	}

	if($tree->{nick}){
		$NICKNAME = $tree->{nick};
	}

	if($tree->{username}){
		$USERNAME = $tree->{username};
	}

	if($tree->{ircname}){
		$IRCNAME = $tree->{ircname};
	}

	if($tree->{server}){
		$SERVER_ADDRESS = $tree->{server};
	}

	if($tree->{port}){
		$SERVER_PORT = $tree->{port};
	}

	if($tree->{password}){
		if($SERVER_PASSWORD ne ''){
			$SERVER_PASSWORD = $tree->{password};
		}
	}


	# SSL Settings

	if($tree->{ssl}->{enable}){
		my $s = $tree->{ssl}->{enable};
		if(($s eq '1')||($s eq '0')){
			if($s eq '1'){
				if(!$SSL_AVAILABLE){
					display_warning("SSL connections are not available. Please install POE::Component::SSLify.");
				} else {
					$USE_SSL = 1;
				}
			}
		} else {
			push(@errors,"ssl.enable must be \"0\" (disable) or \"1\" (enable)");
		}
	}

	if($tree->{ssl}->{key}){
		if($USE_SSL){
			$SSL_KEY = $tree->{ssl}->{key};
			$SSL_KEY = interpolate_directory_symbols($SSL_KEY);
		}
	}

	if($tree->{ssl}->{certificate}){
		if($USE_SSL){
			$SSL_CERT = $tree->{ssl}->{certificate};
			$SSL_CERT = interpolate_directory_symbols($SSL_CERT);
		}
	}

	# Proxy settings

	if($tree->{proxy}->{enable}){
		my $s = $tree->{proxy}->{enable};
		if(($s eq '1')||($s eq '0')){
			if($s eq '1'){
				$USE_PROXY = 1;
			}
		} else {
			push(@errors,"proxy.enable must be \"0\" (disable) or \"1\" (enable)");
		}
	}

	if($tree->{proxy}->{server}){
		if($USE_PROXY){
			$PROXY_SERVER = $tree->{proxy}->{server};
		}
	}

	if($tree->{proxy}->{port}){
		if($USE_PROXY){
			$PROXY_PORT = $tree->{proxy}->{port};
		}
	}

	# Socks settings

	if($tree->{socks}->{enable}){
		my $s = $tree->{socks}->{enable};
		if(($s eq '1')||($s eq '0')){
			if($s eq '1'){
				$USE_SOCKS = 1;
			}
		} else {
			push(@errors,"socks.enable must be \"0\" (disable) or \"1\" (enable)");
		}
	}

	if($tree->{socks}->{server}){
		if($USE_SOCKS){
			$SOCKS_SERVER = $tree->{socks}->{server};
		}
	}

	if($tree->{socks}->{port}){
		if($USE_SOCKS){
			$SOCKS_PORT = $tree->{socks}->{port};
		}
	}

	if($tree->{socks}->{userid}){
		if($USE_SOCKS){
			if($SOCKS_ID ne ''){
				$SOCKS_ID = $tree->{socks}->{userid};
			}
		}
	}

	# Error checking

	if($SERVER_ADDRESS){}else{
		push(@errors,"No IRC server address found");
	}

	if($SERVER_PORT){}else{
		if($USE_SSL){
			display_warning("IRC SSL server port not found; using default port \"$DEFAULT_SSL_IRC_PORT\"");
			$SERVER_PORT = $DEFAULT_SSL_IRC_PORT;
		} else {
			display_warning("IRC server port not found; using default port \"$DEFAULT_IRC_PORT\"");
			$SERVER_PORT = $DEFAULT_IRC_PORT;
		}
	}

	if($USE_PROXY){
		if(($PROXY_SERVER)&&($PROXY_PORT)){}else{
			push(@errors,"Proxy enabled, but no proxy server and/or port found");
		}
	}

	if($USE_SOCKS){
		if($SOCKS_SERVER){}else{
			push(@errors,"SOCKS enabled, but no SOCKS server found");
		}
		if($SOCKS_PORT){}else{
			display_warning("SOCKS server port not found; using default port \"$DEFAULT_SOCKS_PORT\"");
			$SOCKS_PORT = $DEFAULT_SOCKS_PORT;
		}
	}

	if(scalar @errors >=1){
		display_error(@errors);
		exit 1;
	}

	my $IRC = POE::Component::IRC::State->spawn(
		alias => "$SERVER_ADDRESS:$SERVER_PORT",
		nick => $NICKNAME,
		ircname => $IRCNAME,
		username => $USERNAME,
		server  => $SERVER_ADDRESS,
		port => $SERVER_PORT,
		password => $SERVER_PASSWORD,
		NATAddr => $EXTERNAL_IP,
		DCCPorts => \@USE_DCC_PORTS,
		Proxy => $PROXY_SERVER,
		ProxyPort => $PROXY_PORT,
		socks_proxy => $SOCKS_SERVER,
		socks_port => $SOCKS_PORT,
		socks_id => $SOCKS_ID,
		useipv6 => $USE_IPV6,
		Flood => $NO_FLOOD_PROTECTION,
		UseSSL => $USE_SSL,
		SSLCert => $SSL_CERT,
		SSLKey => $SSL_KEY,
		AwayPoll => $AWAY_POLL_TIME,
		Raw => 1,
	) or display_error("PoCo-IRC object creation failed ($!)") && return exit 1;

	my @e = ("$SERVER_ADDRESS:$SERVER_PORT",$IRC);
	push(@PILE,\@e);



	return undef;
}

# parse_dcc_port_list()
# Arguments: 1 (string)
# Returns: Array
# Description: Parses DCC port entries. Entry is a list of
#              numbers seperated by commas. Individial entries
#              can be a single number, or a range of numbers, in
#              the form of "minimum-maximum".
#
# Example Valid Inputs:
# 	10, 20, 30, 40
# 	5
# 	1000-2000,12,6,2100-2101
sub parse_dcc_port_list {
	my $entry = shift;
	my @ports = ();

	foreach my $e (split(',',$entry)){
		if($e=~/\-/){
			my @r = split('-',$e);
			if(scalar @r != 2){
				# malformed entry
			} else {
				if ($r[0] eq int($r[0]) && $r[0] > 0) {}else{
					# $r[0] is not a valid number
				}
				if ($r[1] eq int($r[1]) && $r[1] > 0) {}else{
					# $r[1] is not a valid number
				}
				foreach my $pe ($r[0]..$r[1]){
					push(@ports,$pe);
				}
			}
		} else {
			if ($e eq int($e) && $e > 0) {}else{
				# $e is not a valid number
			}
			push(@ports,$e);
		}
	}

	return @ports;
}

# timestamp()
# Syntax:  print timestamp()."\n";
# Arguments: 0
# Returns:  scalar
# Description:  Generates a timestamp for the current time/date,
#               and returns it.
sub timestamp {
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = gmtime();
	my $year = 1900 + $yearOffset;
	if($second<10){ $second = '0'.$second; }
	if($minute<10){ $minute = '0'.$minute; }
	if($hour<10){ $hour = '0'.$hour; }
	if($month<10){ $month = '0'.$month; }
	if($dayOfMonth<10){ $dayOfMonth = '0'.$dayOfMonth; }
	return "[$hour:$minute:$second $month/$dayOfMonth/$year]";
}

# display_warning()
# Arguments: 1+ (string)
# Returns: Nothing
# Description: Displays a warning.
sub display_warning {
	my $t = timestamp();
	my $indent = ' ' x (length($t)+1);
	if(scalar @_ > 1){
		my @m = ();
		my $e = shift @_;
		push(@m,"$t $e");
		foreach my $el (@_){
			push(@m,$indent.$el);
		}
		foreach my $line (@m){
			if($USE_TERM_COLORS){
				print colored("$line\n",$WARN_COLOR);
			} else {
				print "$line\n";
			}
		}

	} else {
		my $e = shift @_;
		if($USE_TERM_COLORS){
			print colored(timestamp()." $e\n",$WARN_COLOR);
		} else {
			print timestamp()." $e\n";
		}
	}
}

# display_error()
# Arguments: 1+ (string)
# Returns: Nothing
# Description: Displays an error and exits.
sub display_error {

	my $err = join(' ',@_);
	# This is so hacky; v8 throws a segfault when doing a perl exit(),
	# so we're throwing a specifically named error, catching it, and
	# not displaying it. This exits without a segfault.
	if($err=~/exit_throws_a_segfault_so_this_is_how_we_exit_without_throwing_a_segfault_zero/){
		exit 0;
	}
	if($err=~/exit_throws_a_segfault_so_this_is_how_we_exit_without_throwing_a_segfault_one/){
		exit 1;
	}

	my $t = timestamp();
	my $indent = ' ' x (length($t)+1);
	if(scalar @_ > 1){
		my @m = ();
		my $e = shift @_;
		push(@m,"$t $e");
		foreach my $el (@_){
			push(@m,$indent.$el);
		}
		foreach my $line (@m){
			if($USE_TERM_COLORS){
				print colored("$line\n",$ERROR_COLOR);
			} else {
				print "$line\n";
			}
		}

	} else {
		my $e = shift @_;
		if($USE_TERM_COLORS){
			print colored(timestamp()." $e\n",$ERROR_COLOR);
		} else {
			print timestamp()." $e\n";
		}
	}

	exit 1;
}

# verbose()
# Arguments: 1+ (string)
# Returns: Nothing
# Description: Prints to the console if verbose mode is turned on.
sub verbose {
	if($VERBOSE){
		my $t = timestamp();
		my $indent = ' ' x (length($t)+1);
		if(scalar @_ > 1){
			my @m = ();
			my $e = shift @_;
			push(@m,"$t $e");
			foreach my $el (@_){
				push(@m,$indent.$el);
			}
			foreach my $line (@m){
				if($USE_TERM_COLORS){
					print colored("$line\n",$VERBOSE_COLOR);
				} else {
					print "$line\n";
				}
			}

		} else {
			my $e = shift @_;
			if($USE_TERM_COLORS){
				print colored(timestamp()." $e\n",$VERBOSE_COLOR);
			} else {
				print timestamp()." $e\n";
			}
		}
	}
}

# interpolate_directory_symbols()
# Arguments: 1 (scalar string)
# Returns: scalar string
# Description: Interpolates directory symbols into a string:
#                   %INSTALL% - The directory where Libretto is installed
#                   %CONFIG% - The Libretto configuration file directory
#                   %CONNECT% - The directory containing Libretto server connection
#                               configuration files
sub interpolate_directory_symbols {
	my $i = shift;

	my $INSTALL_DIRECTORY = quotemeta '%INSTALL%';
	my $INSTALL_DIRECTORY_PATH = $RealBin;

	my $CONFIGURATION_DIRECTORY = quotemeta '%CONFIG%';
	my $CONFIGURATION_DIRECTORY_PATH = File::Spec->catfile($RealBin,"configuration");

	my $CONNECTION_DIRECTORY = quotemeta '%CONNECT%';
	my $CONNECTION_DIRECTORY_PATH = File::Spec->catfile($RealBin,"configuration","connections");

	$i =~ s/$INSTALL_DIRECTORY/$INSTALL_DIRECTORY_PATH/;
	$i =~ s/$CONFIGURATION_DIRECTORY/$CONFIGURATION_DIRECTORY_PATH/;
	$i =~ s/$CONNECTION_DIRECTORY/$CONNECTION_DIRECTORY_PATH/;

	return $i;
}

# remove_hook()
# Arguments: 1 (hook id)
# Returns: nothing
# Description: Removes one or more event hooks.
sub remove_hook {
	my $id = shift;

	my @h = ();
	foreach my $e (@EVENT_HOOKS){
		my @ea = @{$e};
		if($ea[HOOK_ID] eq $id){ next; }
		push(@h,$e);
	}
	@EVENT_HOOKS = @h;
}

# add_hook()
# Arguments: 3 (hook name,hook id, function name)
# Returns: nothing
# Description: Adds an event hook.
sub add_hook {
	my $t = shift;
	my $id = shift;
	my $c = shift;

	my @e = ($t,$id,$c);
	push(@EVENT_HOOKS,\@e);
}

# get_hooks()
# Arguments: 1 (hook name)
# Returns: array (list of matching hooks)
# Description: Gets all functions for a given hook and returns them.
sub get_hooks {
	my $t = shift;

	my @h = ();
	foreach my $e (@EVENT_HOOKS){
		my @eh = @{$e};
		if($eh[HOOK_TYPE] eq $t){
			push(@h,$eh[HOOK_CODE]);
		}
	}
	return \@h;
}

# remove_zip()
# Arguments: 1 (zip ID)
# Returns: nothing
# Description: Removes a zip file by zip ID
sub remove_zip {
	my $id = shift;
	$ZIP_FILES{$id} = undef;
}

# is_valid_zip()
# Arguments: 1 (zip ID)
# Returns: 1 (if valid) or 0 (if not)
# Description: Determines if a zip ID is valid
sub is_valid_zip {
	my $id = shift;
	if($ZIP_FILES{$id}){ return 1; }
	return 0;
}

# get_zip()
# Arguments: 1 (zip ID)
# Returns: Zip file object
# Description: Gets a zip file by zip ID
sub get_zip {
	my $id = shift;
	return $ZIP_FILES{$id};
}

# create_new_zip()
# Arguments: 1 (filename)
# Returns: String (zip ID)
# Description: Creates a new zip file and file ID
sub create_new_zip {
	my $filename = shift;

	my $zipper = Archive::Zip->new();

	my $r = int(rand(1000));
	while($ZIP_FILES{$r}){
		$r = int(rand(1000));
	}

	if((-e $filename)&&(-f $filename)){
		my $status = $zipper->read($filename);
		if ($status != AZ_OK) {
		    print "Error loading zip file \"$filename\"\n";
		    exit 1;
		}
	}

	my @entry = ($zipper,$filename);
	$ZIP_FILES{$r} = \@entry;
	return $r;
}

sub spawn_new_irc_server {
	my $tree = shift;

	my $SERVER_NAME = undef;
	my $NICKLEN = undef;
	my $NETWORK = undef;
	my $MAXTARGETS = undef;
	my $MAXCHANNELS = undef;
	my $SERVDESC = undef;
	my $PORT = undef;

	if($tree->{name}){
		$SERVER_NAME = $tree->{name};
	} else {
		$SERVER_NAME = 'LibrettoIRCd';
	}

	if($tree->{nicklength}){
		$NICKLEN = $tree->{nicklength};
	} else {
		$NICKLEN = 16;
	}

	if($tree->{network}){
		$NETWORK = $tree->{network};
	} else {
		$NETWORK = 'LibrettoNet';
	}

	if($tree->{maxtargets}){
		$MAXTARGETS = $tree->{maxtargets};
	} else {
		$MAXTARGETS = 10;
	}

	if($tree->{maxchannels}){
		$MAXCHANNELS = $tree->{maxchannels};
	} else {
		$MAXCHANNELS = 16;
	}

	if($tree->{description}){
		$SERVDESC = $tree->{description};
	} else {
		$SERVDESC = 'Libretto IRC Server';
	}

	if($tree->{port}){
		$PORT = $tree->{port};
	} else {
		$PORT = 6667;
	}

	my %config = (
	    servername	=> $SERVER_NAME, 
	    nicklen		=> $NICKLEN,
	    network		=> $NETWORK,
	    maxtargets	=> $MAXTARGETS,
	    maxchannels	=> $MAXCHANNELS,
	    #info		=> \@INFO,
	    #admin		=> \@ADMIN,
	    serverdesc	=> $SERVDESC,
	    #motd 		=> \@MOTD,
	);

	verbose("Starting IRC server on port $PORT");

	my $pocosi = POE::Component::Server::IRC->spawn( config => \%config );

	my @e = ($pocosi, $PORT);
	push(@NEWSERVERS,\@e);
}

sub ircd_daemon_server {
	my ($kernel, $sender, $heap, $name, $introducer, $hops, $desc) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2, ARG3];

		my $ircd = $sender->get_heap();
		my $hostID = $ircd->{hostID};

	verbose("Server $hostID: Server \"$name\" (\"$desc\") connected to the network");

	foreach my $h (@{get_hooks($HOOK_SERVER_JOIN)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'HostID'} = "$hostID";
			$args{'Server'} = "$name";
			$args{'Introducer'} = "$introducer";
			$args{'Hops'} = "$hops";
			$args{'Description'} = "$desc";
			&$h(\%args);
		}
	}

    return;
}

sub ircd_daemon_nick {
    my ( $self, $ircd ) = splice @_, 0, 2;
    if ( $#_ == 7 ) {
        my $nick       = $_[0];
        my $hop_count  = $_[1];
        my $timestamp  = $_[2];
        my $umode      = $_[3];
        my $ident      = $_[4];
        my $hostname   = $_[5];
        my $servername = $_[6];
        my $realname   = $_[7];

        print "New user\n";

    }
    elsif ( $#_ == 1 ) {
        my $nick     = ( split /!/, ${ $_[0] } )[0];
        my $hostmask = ( split /!/, ${ $_[0] } )[1];
        my $newnick  = $_[1];

        print "Nick change\n";
    }

    return;
}

sub ircd_daemon_quit {
    my ($kernel, $sender, $heap, $who, $msg) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

	verbose("Server $hostID: User \"$nick\" quit IRC");

	foreach my $h (@{get_hooks($HOOK_CLIENT_QUIT)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'HostID'} = "$hostID";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Message'} = "$msg";
			&$h(\%args);
		}
	}

    return;
}

sub ircd_daemon_notice {
    my ($kernel, $sender, $heap, $who, $target, $msg) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

    return;
}

sub ircd_daemon_privmsg {
    my ($kernel, $sender, $heap, $who, $spoof, $msg) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

    return;
}

sub ircd_daemon_join {
    my ($kernel, $sender, $heap, $who, $channel) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

	verbose("Server $hostID: User \"$nick\" joined channel \"$channel\"");

	foreach my $h (@{get_hooks($HOOK_CLIENT_JOIN)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'HostID'} = "$hostID";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$channel";
			&$h(\%args);
		}
	}

    return;
}

sub ircd_daemon_umode {
    my ($kernel, $sender, $heap, $who, $mode) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

	verbose("Server $hostID: User \"$nick\" set mode \"$mode\"");

	foreach my $h (@{get_hooks($HOOK_CLIENT_MODE)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'HostID'} = "$hostID";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Mode'} = "$mode";
			&$h(\%args);
		}
	}

    return;
}

sub ircd_daemon_part {
    my ($kernel, $sender, $heap, $who, $channel, $msg) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

	verbose("Server $hostID: User \"$nick\" left channel \"$channel\"");

	foreach my $h (@{get_hooks($HOOK_CLIENT_PART)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'HostID'} = "$hostID";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$channel";
			$args{'Message'} = "$msg";
			&$h(\%args);
		}
	}

    return;
}

sub ircd_daemon_error {
    my ($kernel, $sender, $heap, $connectid, $server, $reason) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

	verbose("Server $hostID: Server \"$server\" had an error: \"$reason\"");

	foreach my $h (@{get_hooks($HOOK_SERVER_ERROR)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'HostID'} = "$hostID";
			$args{'Server'} = "$server";
			$args{'Reason'} = "$reason";
			&$h(\%args);
		}
	}

    return;
}

sub ircd_daemon_squit {
	my ($kernel, $sender, $heap, $server) =
		@_[KERNEL, SENDER, HEAP, ARG0];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

	verbose("Server $hostID: Server \"$server\" quit");

	foreach my $h (@{get_hooks($HOOK_SERVER_QUIT)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'HostID'} = "$hostID";
			$args{'Server'} = "$server";
			&$h(\%args);
		}
	}

    return;
}

sub ircd_daemon_kick {
	my ($kernel, $sender, $heap, $who, $channel, $target, $msg) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2, ARG3];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

	verbose("Server $hostID: User \"$nick\" kicked \"$target\" from channel \"$channel\"");

	foreach my $h (@{get_hooks($HOOK_CLIENT_KICK)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'HostID'} = "$hostID";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$channel";
			$args{'Target'} = "$target";
			$args{'Reason'} = "$msg";
			&$h(\%args);
		}
	}

    return;
}

sub ircd_daemon_mode {
    my ($kernel, $sender, $heap, $who, $channel) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1];
	my @arguments = @_[ARG2..$#_];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

	verbose("Server $hostID: User \"$nick\" set mode".join(' ',@arguments)." on channel \"$channel\"");

	foreach my $h (@{get_hooks($HOOK_CLIENT_CHANNEL_MODE)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'HostID'} = "$hostID";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$channel";
			$args{'Mode'} = \@arguments;
			&$h(\%args);
		}
	}

    return;
}

sub ircd_daemon_topic {
    my ($kernel, $sender, $heap, $who, $channel, $topic) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

	verbose("Server $hostID: User \"$nick\" set topic \"$topic\" on channel \"$channel\"");

	foreach my $h (@{get_hooks($HOOK_CLIENT_TOPIC)}){
		if(ref($h) eq 'CODE'){
			my %args;
			$args{'HostID'} = "$hostID";
			$args{'Nickname'} = "$nick";
			$args{'Hostmask'} = "$hostmask";
			$args{'Channel'} = "$channel";
			$args{'Topic'} = "$topic";
			&$h(\%args);
		}
	}

    return;
}

sub ircd_daemon_public {
    my ($kernel, $sender, $heap, $who, $channel, $msg) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

    return;
}

sub ircd_daemon_invite {
    my ($kernel, $sender, $heap, $who, $spoof, $channel) =
		@_[KERNEL, SENDER, HEAP, ARG0, ARG1, ARG2];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];

	my $ircd = $sender->get_heap();
	my $hostID = $ircd->{hostID};

    return;
}


sub search_for_use_file {
	my $f = shift;

	if((-e $f)&&(-f $f)){ return $f; }

	my $t = File::Spec->catfile($STDLIB,$f);
	if((-e $t)&&(-f $t)){ return $t; }

	$t = File::Spec->catfile($STDLIB,"$f.js");
	if((-e $t)&&(-f $t)){ return $t; }

	$t = File::Spec->catfile($STDLIB,"$f.JS");
	if((-e $t)&&(-f $t)){ return $t; }

	return undef;
}







# ===========================
# | SUPPORT SUBROUTINES END |
# ===========================

__DATA__
<?xml version="1.0"?>

<settings>

	<!--
		IRC settings.

		"nickname" sets the IRC nickname the bot will use. If
		the nick is in use on the server, a short random number
		will be attached to the end of the nick, and this new
		nick will be used.
		"ircname" is a short description of the bot that can
		be seen by other IRC users.
		"username" is a short name that will be used as the
		bot's username (a leftover from when IRC was primarily
		UNIX/Linux based).
	-->
	<nickname>bot</nickname>
	<ircname>libretto irc bot</ircname>
	<username>bot</username>

	<!--
		Turn flood protection on (1) or off (0).
		Turning off flood protection is not recommended,
		and may get you kicked and banned from IRC.
	-->
	<flood-protection>1</flood-protection>

	<!--
		Turn IPv6 support on (1) or off (0).
	-->
	<ipv6>0</ipv6>

	<!--
		Turn verbose mode on (1) or off (0).
		Verbose mode will print various things at runtime
		about what the bot is doing or what is
		happening to or around the bot.
	-->
	<verbose>0</verbose>

	<!--
		Turning warning mode on (1) or off(0).
		This will print warnings when default settings are
		applied, or when non-fatal errors occur.
	-->
	<warnings>0</warnings>

	<!--
		DCC settings
	-->
	<dcc>

		<!--
			Set enable to 1 (one) to turn on DCC connections (the default),
			or 0 (zero) to turn them off
		-->
		<enable>1</enable>

		<!--
			Set which ports to use with DCC.
			Multiple ports can be set if separated by commas, or
			ranges can be set with "minimum-maximum"
		-->
		<ports>10000-11000</ports>

		<!--
			Sets what IP the bot will report to users connecting
			to the bot via DCC. Set "get" to 1 to fetch the bot's
			external IP from an outside source; set "host" to a URL
			that will return the IP of whatever connects to it as
			plain text. If you wish to set the reported IP by manually,
			set "get" to 0 (turning off IP fetching), and set
			"set" to the IP you want the bot to report.
		-->
		<external-ip>
			<get>0</get>
			<host>http://myexternalip.com/raw</host>
			<set></set>
		</external-ip>
	</dcc>

	<color>
		<enable>1</enable>
		<verbose>bold bright_green</verbose>
		<warnings>bold bright_magenta</warnings>
		<errors>bold bright_red</errors>
	</color>

</settings>