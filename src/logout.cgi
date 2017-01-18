#! /usr/bin/perl -wT
################################################################################
#
# Gold logout form
#
# File   :  logout.cgi
# History:  3 MAY 2006 [Scott Jackson] initial implementation
#
################################################################################

use strict;
use vars qw();
use lib qw(/opt/gold/lib /opt/gold/lib/perl5);
use CGI qw(:standard);
use CGI::Session;
use Gold::CGI;
use Gold::Global;

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, { Directory => "/tmp" });
$session->clear(["username"]);
$session->clear(["password"]);

print header;
print start_html(-title => "Session Expired",
                 -onLoad => "top.location.replace(\"login.cgi\");"
);
print end_html;

