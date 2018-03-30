#!/usr/bin/perl -w

#
# chatango.pl (1.00)
#
# Description:
#
# History:
# See ChangeLog.
#
# License:
#
# Bruno <c@ttaneo.uy>
# http://www.cattaneo.uy
# http://github.com/bcattaneo
#

use strict;
use warnings;
use IO::Socket;
use Encode;
use threads;
use Term::ANSIColor qw(:constants); #TODO

use Math::Base36 ':all'; #nuevo
use List::Util qw[min max]; # nuevo

use Tk;

# CUIDADO AL FORMATEAR NUMEROS!!!

###################
## Configuration ##
###################

# Text style
my $font_style 	= "5";			# Font number
my $font_size 	= 14;			# Font size
my $font_color 	= "33363B";		# Text color
my $nick_color 	= "FF8080";		# Nickname color
my $text_style 	= "b";			# Text style ("b" stands for bold, "i" for italic, and "u" for underline. You can also combine them e.g. "biu" in any order)

##########################
## End of Configuration ##
##########################

# Some stuff
my $cookies;
my $auid;
our $conn; 			# Room Connection handler
my @users;			# Stores online users
my @cmd;			# Array with commands to send
my $debug = 1;	# Enables/disables debug

# HTTP stuff
my $agent 			= "Mozilla/5.0 (Windows NT 5.1; rv:16.0) Gecko/20100101 Firefox/16.0";
my $EOL 			= "\015\012";
my $BLANK 			= $EOL x 2;
my $accept 			= "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8";
my $accept_language = "en-US,en;q=0.5";
my $accept_encoding = "gzip, deflate";
my $content_type 	= "application/x-www-form-urlencoded";

# More stuff
my $auth_cookie = "auth.chatango.com";	# Name of the $auid cookie
my $ping_delay 	= 30;					# Default delay between pings
my $bmsg		= "n939";

# Room user input
print "Room: ";
my $room = <STDIN>;
chomp $room;
$room = lc($room);
exit 0 if ($room eq "");
#print "room ".$room."\n";

# # User
# print "User: ";
# my $user = <STDIN>;
# chomp $user;
# exit 0 if ($user eq "");
# #print "user ".$user."\n";

# # Password
# print "Password: ";
# my $password = <STDIN>;
# chomp $password;
# exit 0 if ($password eq "");
# #print "password ".$password."\n";

my $room_srv = chroom($room);
debug("room_srv ".$room_srv."\n");

#test
my $user = "test";
my $password = "fdfsfdsf";

#chconnect($room_srv, 443);

#Login example
 unless (eval {chlogin("$user", "$password");}) {
 	chop $@;
 	print "Error: $@\n";
 }
 else {
 	print "Logged in.\n";
 	chpm("c1.chatango.com",5222)
 }

# # Message input
# while (my $message = <STDIN>) {
	# chomp $message;
	# if ($message ne "") {
		# # If (chcheck()) {
			# print($message);
		# # }
		# # else {
			# # die "Lost connection.\n";
		# # }
	# }
# }

# Login check
# if (chcheck()) {
	# # Message input
	# print ">>> ";
	# while (my $message = <STDIN>) {
		# chomp $message;
		# if ($message ne "") {
			# # If (chcheck()) {
				# print "message ".$message."\n";
				# print ">>> ";
			# # }
			# # else {
				# # die "Lost connection.\n";
			# # }
		# }
	# }
# }
# else {
	# die "Not logged in.\n";
# }

sub ping {

	my $seconds = shift;
	if (!defined($seconds)) {
		$seconds = $ping_delay;		# Default ping delay (seconds)
	}
	while (1) {
		room_cmd();
		debug(">>> Sent a ping");
		sleep $seconds;
	}
}



sub chpm {

	#########################################
	## Handles a connection with PM server ##
	#########################################

	my $host = shift;
	my $port = shift;

	if (defined($host) && defined($port)) {
		my $datos;
		$conn = IO::Socket::INET->new(PeerAddr =>"$host", PeerPort =>"$port", Proto => "tcp");
		unless ($conn) {
			chclose();
			die "Connection error.\n";
		}
		$conn->autoflush(1);
		pm_cmd("tlogin", "$auid"); # OK, FUNCIONA.			ESTO ES DEL PM

		## PARA EL PM
		# while (<$conn>) {
		# 	$datos = "$_";
		# 	print $datos;
		# 	if ($datos =~ /OK/) {
		# 		print "Logged in\n";
		# 		last;
		# 	}
		# 	if ($datos =~ /DENIED/) {
		# 		chclose();
		# 		die "Unknown error (3)\n";
		# 	}
		# }

		#COSAS DEL PM
		pm_msg("prueba123", "hola hola"); # OK, FUNCIONA.
		pm_cmd("wl");			# OK, FUNCIONA. CONTACTOS CONECTADOS (wl:$user:1463697311:on:6), si está desconectado: wl:prueba123:1468725013:off:0
		#pm_cmd("getblock");	# OK, FUNCIONA. LISTA DE BLOQUEADOS? "block_list:usuario"
		#pm_cmd("wladd", "prueba123");	# OK, FUNCIONA. "wladd:prueba123:on:7", si es inválido "wladd:FDFDSFDFSDSDSDSSSS S:invalid:0"
		#pm_cmd("wldelete", "prueba123");	# OK. wldelete:lerougge:deleted:0, si existe, manda igual. si mandás verdura, manda igual
		#pm_cmd("block", "prueba123:prueba123:S");	#OK, funciona. Devuelve getblock luego. Se le mandás verdura devuelve vacío. Si ya está bloqueado devuelve getblock igual
		#pm_cmd("unblock", "prueba123");		# FUNICONA OK, "unblocked:lerougge", si ya existe, devuelve igual. Si mandás verdura, devuelve vacío
		#pm_cmd("track", "prueba123"); # OK, funciona. Te va diciendo el estado de la persona en tiempo real "track:prueba123:1468725013:offline" "idleupdate:lerougge:0"
		# OTROS:
		# cuando te conectás de otro lado, recibís "kickingoff"


		 while (<$conn>) {
		 	$datos = "$_";
		 	print $datos;
		 }

		#close $conn;
		#chclose();
		#die "Connection lost\n";
	}
	else {
		chclose();
		die "URL/cookie/body unspecified.\n";
	}
}

sub chconnect {

	###########################################
	## Handles a connection with room server ##
	###########################################

	my $host = shift;
	my $port = shift;

	if (defined($host) && defined($port)) {
		my $datos;
		my $login;
		my @search;
		my @lines;

		$conn = IO::Socket::INET->new(PeerAddr =>"$host", PeerPort =>"$port", Proto => "tcp");
		unless ($conn) {
			chclose();
			die "Connection error.\n";
		}
		$conn->autoflush(1);

		# Auth into room
		my $uid = int(rand(9999999999999999));
		$uid = sprintf("%.0f", $uid);
		debug("$room, $uid, $user, $password");
		@cmd = ("bauth", $room, $uid, $user, $password); room_cmd(\@cmd, 1);
		#print $conn "bauth:$room:$uid:$user:$password\0";
		# TODO: Handle anon.

		# Gets initial data
		while (sysread($conn, $datos, 64*1024)) {
			my $line;
			my $last = 0;

			# TODO: There's a bug where you get \0 inline so it might miss some messages here.
			@lines = split(/\0/, $datos);
			foreach (@lines) {
				$line = $_;
				debug($line."\n");
				if ($line =~ /:/) {
					@search = split(/:/, $line);
					if ($search[0] eq "ok") {
						if ($search[2] eq $uid) {
							if ($search[3] ne "M") {
								# TODO: Handle anon connection
								chclose();
								die "Wrong username/password\n";
							}
						}
						else {
							chclose();
							die "Unknown error (4)\n";
						}
					}
					elsif ($search[0] eq "i") {
						# TODO: Show last messages?
					}
				}
				elsif ($line =~ /inited/) {
					# Last message from server
					$last = 1;
				}
			}
			if ($last == 1) {
				last;
			}
		}

		# Some initial commands
		@cmd = ("getpremium", "1"); room_cmd(\@cmd);
		#print $conn "getpremium:1\r\n\0";

		# Starts thread that keeps an online users record
		# TODO: Hacerlo, guardarlos en @users

		# Starts the ping thread
		my $pingThread = threads->create(\&ping);

		debug(">>> Connected to $room");

		room_msg("dsds");

		# Incoming data loop
		while (sysread($conn, $datos, 64*1024)) {
			$datos = trim($datos);
			if ($datos eq "") {
				debug("<<< Pong reply from server");
			}
			elsif ($datos eq "verificationrequired") {
				debug("<<< EMAIL VERIFICATION REQUIRED TO POST >>>");
			}
			else {
				debug($datos);
				@search = split(/:/, $datos);
				if ($search[0] eq "b") {

					# Incoming room message
					#my $msg = room_getmsg($datos);      LA IDEA ES QUE ESTE SUB FORMATEE EL MENSAJE PARA DEJARLO TEXTO PLANO O ALGO VISIBLE PARA EL GUI

					my $is_anon = 0;
					my $l_sender = $search[2];		# Lowercase sender
					if ($l_sender eq "" && $search[3] ne "") {
						# Anon with nick
						$l_sender = $search[3]; # anonymous nickname
						$is_anon = 1;
					}
					elsif ($l_sender eq "" && $search[3] eq "") {
						# Anon without nick
						# TODO: Get real anon ID (still have to figure out how)
						$l_sender = "anon";
						$is_anon = 1;
					}
					my $sender	= uc($l_sender);	# Uppercase sender
					my $u_user = uc($user);			# Uppercase user
					print($sender."\n");
					print($user."\n");
					print($is_anon."\n");
					if ($sender ne uc($user)) {		# To skip our own messages
						# HACER COSAS ACÁ
						print($datos."\n");
					}
				}
				elsif ($search[0] eq "n") {
					# TODO: en cada conexión/desconexión se recibe "n:NÚMERO". Llevar el conteo
					debug("<<< Online users: $search[1]");
				}
			}
		}

		#close $conn;
		#chclose();
		#die "Connection lost\n";
	}
	else {
		chclose();
		die "Host/port unspecified.\n";
	}
}

######################
## Room subroutines ##
######################

sub room_msg {

	#####################################
	## Sends a message to current room ##
	#####################################

	# TODO: Do it with try in case of connection lost.

	my $msg = shift;

	# Determines text style
	if (uc($text_style) =~ /B/) {$msg = "<b>".$msg."</b>";}
	if (uc($text_style) =~ /U/) {$msg = "<u>".$msg."</u>";}
	if (uc($text_style) =~ /I/) {$msg = "<i>".$msg."</i>";}

	print $conn "bmsg:$bmsg:<n$nick_color/><f x$font_size$font_color=\"$font_style\">$msg</f>\r\n\0";
}

sub room_cmd {

	#####################################
	## Sends a command to current room ##
	#####################################

	# TODO: Do it with try in case of connection lost.

	my ($incmd, $first) = @_;
	my @commands;

	if (defined($incmd)) {
		@commands = @{$incmd};
	}

	my $ending;
	my $msg = "";

	if (@commands) {
		if (defined($first) && $first == 1) {
			$ending = "\0";
		}
		else {
			$ending = "\r\n\0";
		}
		foreach (@commands) {
			if ($msg eq "") {
				$msg = "$_";
			}
			else {
				$msg = $msg.":"."$_";
			}
		}
		$msg = $msg.$ending;
		print $conn $msg;
	}
	else {
		# Sends an empty message (ping)
		print $conn "\r\n\0";
	}
}

####################
## PM subroutines ##
####################

sub pm_cmd {
	my $command = shift;
	my $msg = shift;
	if (defined($msg)) {
		print $conn "$command:$msg:2\r\n\0";
	}
	else {
		print $conn "$command:2\r\n\0";
	}
}

sub pm_msg {
	my $target = shift;
	my $msg = shift;
	print $conn "msg:$target:$msg\r\n\0";
}


###########
## Other ##
###########

sub chroom {

	#########################################
	## Gets room server based on room name ##
	#########################################

	my $room = shift;
	my %weights = ("5", 75, "6", 75, "7", 75, "8", 75, "16", 75, "17", 75, "18", 75, "9", 95, "11", 95, "12", 95, "13", 95, "14", 95, "15", 95, "19", 110, "23", 110, "24", 110, "25", 110, "26", 110, "28", 104, "29", 104, "30", 104, "31", 104, "32", 104, "33", 104, "35", 101, "36", 101, "37", 101, "38", 101, "39", 101, "40", 101, "41", 101, "42", 101, "43", 101, "44", 101, "45", 101, "46", 101, "47", 101, "48", 101, "49", 101, "50", 101, "52", 110, "53", 110, "55", 110, "57", 110, "58", 110, "59", 110, "60", 110, "61", 110, "62", 110, "63", 110, "64", 110, "65", 110, "66", 110, "68", 95, "71", 116, "72", 116, "73", 116, "74", 116, "75", 116, "76", 116, "77", 116, "78", 116, "79", 116, "80", 116, "81", 116, "82", 116, "83", 116, "84", 116);
	my @weights = ("5", 75, "6", 75, "7", 75, "8", 75, "16", 75, "17", 75, "18", 75, "9", 95, "11", 95, "12", 95, "13", 95, "14", 95, "15", 95, "19", 110, "23", 110, "24", 110, "25", 110, "26", 110, "28", 104, "29", 104, "30", 104, "31", 104, "32", 104, "33", 104, "35", 101, "36", 101, "37", 101, "38", 101, "39", 101, "40", 101, "41", 101, "42", 101, "43", 101, "44", 101, "45", 101, "46", 101, "47", 101, "48", 101, "49", 101, "50", 101, "52", 110, "53", 110, "55", 110, "57", 110, "58", 110, "59", 110, "60", 110, "61", 110, "62", 110, "63", 110, "64", 110, "65", 110, "66", 110, "68", 95, "71", 116, "72", 116, "73", 116, "74", 116, "75", 116, "76", 116, "77", 116, "78", 116, "79", 116, "80", 116, "81", 116, "82", 116, "83", 116, "84", 116);

	my $srv = 0;

	my $room_a = $room;
	$room_a =~ s/\Q_\E/q/g;		# replaces "_"
	$room_a =~ s/\Q-\E/q/g;		# replaces "-"
	$room_a = sprintf("%.1f", decode_base36(substr($room_a, 0, min(5, length($room_a)))));
	debug($room_a."\n");

	my $room_b = 0;
	if (length($room) > 6) {
		$room_b = substr($room,6, (6 + min(3, (length($room) - 5))) - 6);
		$room_b = decode_base36($room_b);
		$room_b = max($room_b, 1000)
	}
	else {
		$room_b = 1000;
	}
	$room_b = sprintf("%.1f", $room_b);	# lo dejo X.X
	debug($room_b."\n");

	my $room_c = sprintf("%f", ($room_a % $room_b) / $room_b);	# lo dejo X
	debug($room_c."\n");

	# Max num
	my $sum = 0;
	while (my ($key, $value) = each(%weights)) {
		$sum += $value;
	}
	$sum = sprintf("%f", $sum);	# lo dejo X.X
	debug("sum ".$sum."\n");

	# srv
	# TODO: Use the same associative array with a proper order.
	my $freq = 0;
	my $value = 0;
	while (my $key = shift @weights){
		$value = shift(@weights);
		$value = sprintf("%f", $value);
		$freq += ($value / $sum);
		#debug("freq ".$freq."\n");
		if ($room_c <= $freq) {
			$srv = $key;
			last;
		}
	}
	debug("srv ".$srv."\n");
	return("s".$srv.".chatango.com")
}

sub chpost {

	######################
	## HTTP POST Method ##
	######################

	my $url = shift;
	my $cookie = shift;
	my $cuerpo = shift;
	my $host = shift;
	my $alive = shift;
	my $referer = shift;
	if (defined($url) && defined($cookie) && defined($cuerpo) && $url ne "" && $cuerpo ne "") {
		my $datos;
		$cuerpo = encode("utf-8", $cuerpo);
		my $sock = IO::Socket::INET->new(PeerAddr =>"www.chatango.com", PeerPort =>"http(80)", Proto => "tcp");
		unless ($sock) {
			chclose();
			die "Connection error.\n";
		}
		$sock->autoflush(1);
		print $sock "POST $url HTTP/1.0" . $EOL;
		if (defined($host) && $host ne "") {
			print $sock "Host: $host" . $EOL;
		}
		else {
			print $sock "Host: chatango.com" . $EOL;
		}
		print $sock "User-Agent: $agent" . $EOL;
		print $sock "Accept: $accept" . $EOL;
		print $sock "Accept-Language: $accept_language" . $EOL;
		print $sock "Accept-Encoding: $accept_encoding" . $EOL;
		if ($referer ne "") {
			print $sock "Referer: $referer" . $EOL;
		}
		if ($cookie ne "") {
			print $sock "Cookie: $cookie" . $EOL;
		}
		if (defined($alive) && $alive == 1) {
			print $sock "Connection: keep-alive" . $EOL;
		}
		else {
			print $sock "Connection: close" . $EOL;
		}
		print $sock "Content-Type: $content_type" . $EOL;
		print $sock "Content-Length: " . length($cuerpo) . $BLANK;
		print $sock "$cuerpo" . $EOL;
		while (<$sock>) {
			$datos = "$datos$_";
		}
		close $sock;
		return $datos;
	}
	else {
		die "URL/cookie/cuerpo unspecified.\n";
	}
}


sub chlogin {

	##########################
	## Gets the auth cookie ##
	##########################

	my $user = shift;
	my $pass = shift;
	if (defined($user) && defined($pass) && $user ne "" && $pass ne "") {
		chclose();
		my $datos;
		unless (eval {$datos = chpost("/login", "", "user_id=$user&password=$pass&storecookie=on&checkerrors=yes", "chatango.com", 1, "http://chatango.com/login");}) {
			chclose();
			chop $@;
			die "$@.\n";
		}
		if ($datos =~ /200 OK/) {
			# We're in
			# Getting cookies...
			for (split /$EOL/, $datos) {
				my $cookie1 = $_;
				$cookie1 =~ s/\s+$//;
				if ($cookie1 =~ /Set-Cookie: (.*)/) {
					my $cookie2 = $1;
					if ($cookie2 !~ /deleted/) {
						my @cookie3 = split(" ", $cookie2);
						if (defined($cookies)) {
							$cookies = "$cookies $cookie3[0]";
						}
						else {
							$cookies = "$cookie3[0]";
						}
					}
				}
			}
			$cookies =~ s/\;+$//g;

			if ($cookies =~ /$auth_cookie=(.*?)\;/o) {
				$auid = $1;
				if ($auid ne "") {
					return 1;
				}
				else {
					chclose();
					die "Wrong username/password.\n";
				}
			}
			else {
				chclose();
				die "Unknown error (1).\n";
			}
			return 1;
		}
		else {
			chclose();
			die "Unknown error (2).\n";
		}
	}
	else {
		chclose();
		die "Username/password unspecified.\n";
	}
}

sub chclose {
	undef($cookies);
	undef($auid);
	# TODO: Tendría que parar algunos threads, el de ping, el que va a estar revisando usuarios, etc.
}

sub chcheck {
	if (defined($cookies) && defined($auid)) {
		return 1;
	}
	else {
		return 0;
	}
}

sub chget {

	#####################
	## HTTP GET Method ##
	#####################

	my $url = shift;
	my $cookie = shift;
	my $host = shift;
	my $alive = shift;
	if (defined($url) && defined($cookie) && $url ne "") {
		# Loop
		while (1) {
			my $datos;
			my $sock = IO::Socket::INET->new(PeerAddr =>"www.chatango.com", PeerPort =>"http(80)", Proto => "tcp");
			unless ($sock) {
				chclose();
				die "Connection error.\n";
			}
			$sock->autoflush(1);
			print $sock "GET $url HTTP/1.1" . $EOL;
			if (defined($host) && $host ne "") {
				print $sock "Host: $host" . $EOL;
			}
			else {
				print $sock "Host: chatango.com" . $EOL;
			}
			print $sock "User-Agent: $agent" . $EOL;
			print $sock "Accept: text/html,application/xhtml+xml,application/xml,application/ecmascript,text/javascript,text/jscript;q=0.9,*/*;q=0.8" . $EOL;
			print $sock "Accept-Language: en-us,en;q=0.5" . $EOL;
			print $sock "Accept-Encoding: deflate" . $EOL;
			print $sock "Accept-Charset: UTF-8;q=0.7,*;q=0.7" . $EOL;
			if ($cookie ne "") {
				print $sock "Cookie: $cookie" . $EOL;
			}
			if (defined($alive) && $alive == 1) {
				print $sock "Connection: keep-alive" . $BLANK;
			}
			else {
				print $sock "Connection: close" . $BLANK;
			}
			while (<$sock>) {
				$datos = "$datos$_";
			}
			if ($datos =~ /Location: (.*?)$EOL/o) {
				$url = $1;
				close $sock;
				# Back to loop
			}
			else {
				close $sock;
				# Decode it for your own needs.
				#$datos = decode("utf-8", $datos);
				return "$datos";
			}
		}
	}
	else {
		die "URL/cookie/body unspecified.\n";
	}
}

sub trim {

	############################################
	## Removes unwanted starting/ending chars ##
	############################################

	my $text = shift;
	$text =~ s/^\s+|\s+$//g;
	$text =~ s/^\n+|\n+$//g;
	$text =~ s/^\0+|\0+$//g;
	return $text;
}

sub debug {
	my $debug_msg = shift;
	if (defined($debug_msg) && $debug == 1) {
		print "$debug_msg\n";
	}
}
#EOF
