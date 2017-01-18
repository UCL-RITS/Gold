#! /usr/bin/perl -wT
################################################################################
#
# Gold login form
#
# File   :  login.cgi
# History:  20 APR 2005 [Scott Jackson] initial implementation
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
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use CGI::Session;
use Gold::CGI;
use Gold::Global;

my $cgi = new CGI;
my $username = $cgi->param("username");
my $password = $cgi->param("password");

# If this script was not called with username then display login form
if (! $username)
{
  printLoginHeader();
  printLoginForm();
}
# If username was supplied but not a password then redisplay with a message
elsif (! $password)
{
  printLoginHeader();
  print font( { -color => "red" }, "You must supply a password");
  printLoginForm();
}
# If a username and password were supplied, then test authentication
else
{
  # Test authentication by querying RoleUsers
  my $request = new Gold::Request(object => "RoleUser", action => "Query", actor => $username);
  my $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
  $messageChunk->setRequest($request);
  my $replyChunk = $messageChunk->getChunk();
  my $response = $replyChunk->getResponse();
  my $status = $response->getStatus();

  # If authentication failed, then redisplay login form with a message
  if ($status eq "Failure")
  {
    printLoginHeader();
    my $message = $response->getMessage();
    if ($message =~ /Failed authenticating message/)
    {
      $message = "You have supplied an invalid username or password.";
    }
    print font( { -color => "red" }, $message);
    printLoginForm();
  }

  # If authentication succeeded, start a new session and redirect to welcome
  else
  {
    # Start a new session and redirect to gold frameset
    my $session = new CGI::Session(undef, undef, { Directory => "/tmp" });
    $session->expire("+1d");
    $session->param("username", $username);
    $session->param("password", "$password");
    my $cookie = $cgi->cookie(CGISESSID => $session->id);
    print redirect(-cookie => $cookie, -location => "index.cgi");
  }
}

sub printLoginHeader
{
  print header,
    start_html(-title => "Gold Login",
               -style => { -src => "/cgi-bin/gold/styles/gold.css" }
    ),
    div( { -align => "center" },
      table(
        Tr(
          td( { -align => "center"}, img({-src => "/cgi-bin/gold/images/gold_logo_globe.gif"}))
        ), # end Tr
        Tr( td( h1("Accounting and Allocation Manager") ) )
      ) # end table
    ), # end div
    br;
}

sub printLoginForm
{
  print h2("Please Log In:"),
    start_form( { -action  => "login.cgi",
                  -enctype => "application/x-www-form-urlencoded",
                  -method  => "post" } ),
    table(
      Tr(
        td(
          table( { -border      => "1",
                   -bgcolor     => "gold" },
            Tr(
              td(
                table( { -bgcolor     => "#000000",
                         -border      => "0",
                         -cellpadding => "2",
                         -cellspacing => "0",
                         -style       => "font: 10pt;" },
                  Tr( { -style => "background-color: #EFEBAB" },
                    td( strong( "Gold Username:" ) ),
                    td(
                      input( { -maxlength => "30",
                               -name      => "username",
                               -size      => "30",
                               -type      => "text"} ) )
                    ), # end td
                  Tr( { -style => "background-color: #EFEBAB"},
                    td( strong( "Gold Password:" ) ),
                    td(
                      input( { -maxlength => "30",
                               -name      => "password",
                               -size      => "30",
                               -type      => "password"} )
                    ) # end td
                  ) # end Tr
                ) # end table
              ) # end td
            ) # end Tr
          ), # end table
        ) # end td
      ), # end Tr
      Tr(
        td( { -align => "center" },
          input( { -type  => "submit",
                   -value => "Login",
                   -style => "background-color: #EFEBAB"} )
        ) # end td
      ) # end Tr
    ), # end table
    end_form,
    br,
    p( b("Hint: If you do not know your password, use ", i("gchpasswd"), " to set a new password for Gold." ) ),
    end_html;
}


