#! /usr/bin/perl -wT
################################################################################
#
# Status Frame for Gold Web GUI
#
# File   :  status.cgi
# History:  12 MAY 2005 [Scott Jackson] first implementation
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
use XML::LibXML;

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, { Directory => "/tmp" });
unless ($session->param("username") && $session->param("password"))
{
  print redirect(-location => "login.cgi");
  exit(0);
}

my $message = $cgi->param("message");
my $data = $cgi->param("data");

# Render the statusbar content
print header;
print start_html(-title => "Gold Status Bar",
                 -style => { -src => "/cgi-bin/gold/styles/status.css" } );
print_message() if $message;
print_data() if $data;
print end_html;

# Print the Message
sub print_message {
  print $message;
}

# Render the data in a table
sub print_data {
  my $parser = new XML::LibXML();
  my $doc = $parser->parse_string($data);
  my $root = $doc->getDocumentElement();

  # Convert xml data into a table
  my $table = "";
  my @rows = $root->childNodes();
  if (@rows > 0)
  {
    # Print Table Header
    $table .= <<END_OF_TABLE_TOP;
  <table id="results" border="0" cellspacing="0">
    <thead>
      <tr>
END_OF_TABLE_TOP
    foreach my $col (($rows[0])->childNodes())
    {
      my $name = $col->nodeName();
      $table .= "      <td><div>$name</div></td>\n";
    }
    $table .= "    </tr>\n  </thead>\n";

    # Print Table Body
    $table .= "  <tbody>\n";
    foreach my $row (@rows)
    {
      $table .= "    <tr>\n";
      foreach my $col ($row->childNodes())
      {
        my $name = $col->nodeName();
        my $value = $col->textContent();
        $value = "&nbsp;" if $value eq ""; # So border will be drawn
        $table .= "      <td>$value</td>\n";
      }
      $table .= "    </tr>\n";
    }
    $table .= "  </tbody>\n</table>\n";
  }

  print "<p>$table";
}

