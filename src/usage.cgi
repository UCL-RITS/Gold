#! /usr/bin/perl -wT
################################################################################
#
# Usage Frame for Gold Web GUI
#
# File   :  usage.cgi
# History:  28 JUL 2005 [Scott Jackson] first implementation
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
use Gold::CGI;
use Gold::Global;

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, { Directory => "/tmp" });
my $username = $session->param("username");
my $password = $session->param("password");
unless ($username && $password)
{
  print header;
  print start_html(-title => "Session Expired",
                   -onLoad => "top.location.replace(\"login.cgi\");"
  );
  print end_html;
  exit(0);
}

my $object = $cgi->param("myobject");
my $action = $cgi->param("myaction");
my $project = $cgi->param("Project");
my $startTime = $cgi->param("StartTime");
my $endTime = $cgi->param("EndTime");
my $display = $cgi->param("display");

my $style_sheet = <<END_STYLE_SHEET;
<!--
    \@import "/cgi-bin/gold/styles/gold.css";

    h1 {
      font-size: 110%;
      text-align: center;
    }

    .multiSelect {
      margin-top: 1em;
    }

    .multiSelect label {
      font-weight: bold;
      display: block;
    }

    .include {
      width: 100%;
    }

    .include {
      float: left;
    }


    .include select{
      width: 100%;
    }

    #includeHead, #excludeHead {
      border-bottom: 1px solid black;
      margin-top: 10px;
      margin-bottom: 2px;
      font-weight: bold;
      font-size: 110%;
    }

    html&gt;body #includeHead, html&gt;body #excludeHead {
      margin-top: 0px;
    }
    
    th {
      font-weight: bold;
      text-align: center;
      vertical-align: bottom;
      background-color: #EFEBAB;
      white-space: nowrap;
    }
    
    table, th, td {
      border: 1px solid black;
      border-collapse: collapse;
    }
    
    th, td {
      padding: 6px;
      font-size: 70%;
    }
    
    .amount {
      text-align: right;
    }
    
    .totals td {
      border-top: 3px double black;
      font-weight: bold;
      background-color: #C1DDFD;
    }
    
    #available {
      font-size: 80%;
      margin-top: 2em;
      line-height: 150%;
    }
    
    table, #available {
      margin-left: 82px;
    }
    
    #accounts {
      margin-top: 2em;
    }

-->
END_STYLE_SHEET

print header;
print start_html(-title => "Usage Report",
                 -style => { -code => $style_sheet }
  );
print_body();
print end_html;

sub print_body {

  # Print the header
  print div( { -class => "header" },
    div( { -class => "leftFlare" },
      img( { -alt => "",
             -height => "36",
             -width => "16",
             -src => "/cgi-bin/gold/images/header_flare_left.gif" } ) ),
    div( { -class => "rightFlare" },
      img( { -alt => "",
             -height => "36",
             -width => "16",
             -src => "/cgi-bin/gold/images/header_flare_right.gif" } ) ),
    h1("Usage Report") );

  # Print the usage form
  print <<END_OF_SCREEN_TOP;
<form name="inputForm" method="post" action="usage.cgi">
  <input type="hidden" name="myobject" value="$object">
  <input type="hidden" name="myaction" value="$action">
  <input type="hidden" name="display" value="True">
END_OF_SCREEN_TOP

  # Print Project Select
  print <<END_OF_SCREEN_SECTION;
    <div class="row">
      <div id="MultiProjectSelect" class="multiSelect">
        <label class="rowLabel" for="name(./*[1])">Projects:</label>
        <select id="Project" name="Project">
          <option value="">All Projects</option>
END_OF_SCREEN_SECTION

  # Project Query Special==False
  my $request = new Gold::Request(object => "Project", action => "Query", actor => $username);
  $request->setSelection("Name");
  $request->setCondition("Special", "False");
  my $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
  $messageChunk->setRequest($request);
  my $replyChunk = $messageChunk->getChunk();
  my $response = $replyChunk->getResponse();
  my $status = $response->getStatus();
  my $message = $response->getMessage();
  my $data = $response->getDataElement();
  my $count = $response->getCount();
  my $doc = XML::LibXML::Document->new();
  $doc->setDocumentElement($data); 

  foreach my $row ($data->childNodes())
  {
    my $selected = "";
    my $value = ($row->childNodes())[0]->textContent();
    if ($value eq $project) { $selected = " SELECTED"; }
    print "        <option value=\"$value\"$selected>$value</Option>\n";
  }

  print <<END_OF_SCREEN;
    </select>
    </div>
  </div
  <div class="row">
    <label for="StartTime" class="rowLabel">Start Date:</label>
    <input type="text" name="StartTime" id="StartTime" value="" size="30" maxlength=""/>
  </div>
  <div class="row">
    <label for="EndTime" class="rowLabel">End Date:</label>
    <input type="text" name="EndTime" id="EndTime" value="" size="30" maxlength=""/>
  </div>
  <div id="submitRow">
    <input value="Generate Report" type="submit"/>
  </div>
</form>
END_OF_SCREEN

  if ($display)
  {
    print "<hr/>\n";

    unless ($startTime) { $startTime = "-infinity"; }
    unless ($endTime) { $endTime = "now"; }

    # Transaction Query Object==Job Action==Charge Project=$project CreationTime>=$startTime CreationTime<$endTime Show:="GroupBy(User),Sum(Amount)"
    my $request = new Gold::Request(object => "Transaction", action => "Query", actor => $username);
    $request->setSelection("User", "GroupBy");
    $request->setSelection("Amount", "Sum", "", "Usage");
    $request->setSelection("Amount", "Count", "", "Jobs");
    $request->setSelection("Amount", "Average", "", "Average");
    $request->setCondition("Object", "Job");
    $request->setCondition("Action", "Charge");
    $request->setCondition("Project", $project) if $project;
    $request->setCondition("CreationTime", $startTime, "GE");
    $request->setCondition("CreationTime", $endTime, "LT");
    my $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
    $messageChunk->setRequest($request);
    my $replyChunk = $messageChunk->getChunk();
    my $response = $replyChunk->getResponse();
    my $status = $response->getStatus();
    my $message = $response->getMessage();
    my $data = $response->getDataElement();
    my $count = $response->getCount();
    my $doc = XML::LibXML::Document->new();
    $doc->setDocumentElement($data); 

    my @rows = $data->childNodes();
    if (@rows > 0)
    {
      print <<END_OF_TABLE;
    <table id="usage" cellspacing="0">
      <tr>
END_OF_TABLE

      foreach my $col (($rows[0])->childNodes())
      {
        my $name = $col->nodeName();
        print "        <th>$name</th>\n";
      }
      print "      </tr>\n";

      foreach my $row (@rows)
      {
        print "      <tr>\n";
        foreach my $col ($row->childNodes())
        {
          my $value = $col->textContent();
          print "        <td>$value</td>\n";
        }
        print "      </tr>\n";
      }
      print "    </table>\n";
    }
  }
}

