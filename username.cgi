#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use CGI::Cookie;

my $cgi = CGI->new();

my $set = $cgi->param('set') || '';
my $username = $cgi->param('username') || '';

my ($cookie, %cookies, $cookieset);

if (!$set) {
	print "Content-Type: text/html; charset=utf-8\n\n";
	print <<HTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="en-gb">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<title>Username - set cookie</title>
	<link rel="stylesheet" type="text/css" href="http://grault.net/grubstreet/grubstreet.css" title="stylesheet">
</head>
<body>
<div id="content">
<h1>Username</h1>
<p>
Use this form to set a cookie in your browser of how you wish to be
identified in Recent Changes.
</p> 
<form action="username.cgi" method="post">
<input type="text" size="20" name="username"> 
<input type="submit" value="Set it">
<input type="hidden" name="set" value="yes">
</form>
</div>
</body>
</html>
HTML

}

else {
	&set_cookie;
	print "Content-Type: text/html; charset=utf-8\n\n";

	print <<HTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="en-gb">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<title>Username - cookie delivered</title>
	<link rel="stylesheet" type="text/css" href="http://grault.net/grubstreet/grubstreet.css" title="stylesheet">
</head>
<body>
<div id="content">
<h1>Cookie set</h1>
<p>
You set 
HTML

if ($cookieset eq "") {
	print "\"$username\"";
}
else {
	print '"' . &get_cookie . '"';
}

print <<HTML;
 as your username.
</p>
<p>
<a href="wiki.cgi">Return to the wiki</a>
</p>
</div>
</body>
</html>
HTML

}

sub set_cookie {
	$cookie = CGI::Cookie->new(	-name    =>  'username',
					-value   =>  $username,
					-expires =>  '+12M' );
	
	print "Set-Cookie: $cookie\n";
}

sub get_cookie {
	%cookies = fetch CGI::Cookie;
	$cookieset = $cookies{'username'}->value;
	return $cookieset;
}
