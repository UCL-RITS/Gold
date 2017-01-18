#! /usr/bin/perl -wT
################################################################################
#
# Frameset for Gold Web GUI
#
# File   :  index.cgi
# History:  14 APR 2005 [Scott Jackson] first implementation
#
################################################################################
#                                                                              #
#                              Copyright (c) 2005                              #
#                  Pacific Northwest National Laboratory,                      #
#                         Battelle Memorial Institute.                         #
#                             All rights reserved.                             #
#                                                                              #
################################################################################
#                                                                              #
#     Redistribution and use in source and binary forms, with or without       #
#     modification, are permitted provided that the following conditions       #
#     are met:                                                                 #
#                                                                              #
#     · Redistributions of source code must retain the above copyright         #
#     notice, this list of conditions and the following disclaimer.            #
#                                                                              #
#     · Redistributions in binary form must reproduce the above copyright      #
#     notice, this list of conditions and the following disclaimer in the      #
#     documentation and/or other materials provided with the distribution.     #
#                                                                              #
#     · Neither the name of Battelle nor the names of its contributors         #
#     may be used to endorse or promote products derived from this software    #
#     without specific prior written permission.                               #
#                                                                              #
#     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS      #
#     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT        #
#     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS        #
#     FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE           #
#     COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,      #
#     INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,     #
#     BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;         #
#     LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER         #
#     CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT       #
#     LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN        #
#     ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE          #
#     POSSIBILITY OF SUCH DAMAGE.                                              #
#                                                                              #
################################################################################

use strict;
use vars qw();
use lib qw(/opt/gold/lib /opt/gold/lib/perl5);
use CGI qw(:standard);
use CGI::Session;

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, { Directory => "/tmp" });
unless ($session->param("username") && $session->param("password"))
{
  print redirect(-location => "login.cgi");
  exit(0);
}

print $cgi->header;
print_frameset();

# Print the frameset
sub print_frameset {
  print <<EOF;
<html>
  <head>
    <title>Welcome to Gold</title>
  </head>
  <frameset cols="190,*" framespacing="0" border="1">
    <frame src="navbar.cgi" name="navbar" scrolling="auto" frameborder="0" title="Navigation Frame">
    <frameset rows="3*,*" framespacing="0" border="1">
      <frame src="welcome.cgi" name="action" scrolling="yes" frameborder="0" title="Action Frame">
      <frame src="status.cgi" name="statusbar" scrolling="yes" frameborder="0" title="Status Frame">
      <noframes>
You must have a frames-capable browser to use the Gold Web Interface.  Please download the latest version of <a href="http://www.mozilla.org">Mozilla</a>, <a href="http://www.netscape.com">Netscape</a>, or <a href="http://www.microsoft.com/windows/ie/default.htm">Internet Explorer</a>.
      </noframes>
    </frameset>
    <noframes>
You must have a frames-capable browser to use the Gold Web Interface.  Please download the latest version of <a href="http://www.mozilla.org">Mozilla</a>, <a href="http://www.netscape.com">Netscape</a>, or <a href="http://www.microsoft.com/windows/ie/default.htm">Internet Explorer</a>.
    </noframes>
  </frameset>
</html>
EOF
    exit 0;
}


