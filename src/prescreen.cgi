#! /usr/bin/perl -wT
################################################################################
#
# Prescreen Condition Frame for Gold Web GUI
#
# File   :  prescreen.cgi
# History:  26 MAY 2005 [Scott Jackson] first implementation
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

my $objects_ref = $session->param("objects");
my %objects = %{$objects_ref};
my $actions_ref = $session->param("actions");
my %actions = %{$actions_ref};
my $attributes_ref = $session->param("attributes");
my %attributes = %{$attributes_ref};
my $object = $cgi->param("myobject");
my $action = $cgi->param("myaction");

my $style_sheet = <<END_STYLE_SHEET;
<!--
    \@import "/cgi-bin/gold/styles/gold.css";

    body {
        background-color: white;
    }
                                                                                
    h1 {
        font-size: 110%;
        text-align: center;
    }

    .multiSelect {
        width: 32%;
        float: left;
        margin-bottom: 2em;
    }
                                                                            
    .multiSelect select {
        width: 90%;
    }
                                                                            
    .multiSelect label {
        font-weight: bold;
        display: none;
    }

-->
END_STYLE_SHEET

print header;
print start_html(-title => "Prefilter ${object}s",
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
    h1("Prefilter ${object}s") );

  # Print the prescreen form
  print <<END_OF_SCREEN_TOP;
<form name="screenForm" method="post" action="list.cgi">
  <input type="hidden" name="myobject" value="$object">
  <input type="hidden" name="myaction" value="$action">
END_OF_SCREEN_TOP

  # Objects
  if ($object eq "Transaction")
  {
    print <<END_OF_SCREEN_SECTION;
  <div class="row">
    <div id="ObjectMultiSelect" class="multiSelect">
      <label class="rowLabel" for="name(./*[1])">Objects:</label>
      <select id="Object" name="ObjectCondition">
        <option value="">ANY</option>
END_OF_SCREEN_SECTION
    foreach my $obj (sort keys %objects)
    {
      print "        <option value=\"$obj\">$obj</option>\n";
    }
    print "      </select>\n    </div>\n  </div>\n";
  }

  # Actions
  if ($object eq "Transaction")
  {
    print <<END_OF_SCREEN_SECTION;
  <div class="row">
    <div id="ActionMultiSelect" class="multiSelect">
      <label class="rowLabel" for="name(./*[1])">Actions:</label>
      <select id="Action" name="ActionCondition">
        <option value="">ANY</option>
END_OF_SCREEN_SECTION
    my %uniqueActions = ();
    foreach my $obj (keys %actions)
    {
      foreach my $act (keys %{$actions{$obj}})
      {
        next if $act eq "NONE";
        next if $act eq "ANY";
        $uniqueActions{$act}++;
      }
    }
    foreach my $act (sort keys %uniqueActions)
    {
      print "        <option value=\"$act\">$act</option>\n";
    }
    print "      </select>\n    </div>\n  </div>\n";
  }

  # StartTime
  print <<END_OF_SCREEN_SECTION;
  <div class="row">
    <label class="rowLabel" for="StartTime">Start Time (YYYY-MM-DD):</label>
    <input maxlength="" size="30" value="" id="StartTime" name="StartTimeCondition" type="text"/>
  </div>
END_OF_SCREEN_SECTION

  # EndTime
  print <<END_OF_SCREEN_SECTION;
  <div class="row">
    <label class="rowLabel" for="EndTime">End Time (YYYY-MM-DD):</label>
    <input maxlength="" size="30" value="" id="EndTime" name="EndTimeCondition" type="text"/>
  </div>
END_OF_SCREEN_SECTION

  # JobId
  if ($object eq "Transaction" || $object eq "Job")
  {
    print <<END_OF_SCREEN_SECTION;
  <div class="row">
    <label class="rowLabel" for="JobId">Job Id:</label>
    <input maxlength="" size="30" value="" id="JobId" name="JobIdCondition" type="text"/>
  </div>
END_OF_SCREEN_SECTION
  }

  # Account
  if ($object eq "Transaction")
  {
    print <<END_OF_SCREEN_SECTION;
  <div class="row">
    <label class="rowLabel" for="Account">Account Id:</label>
    <input maxlength="" size="30" value="" id="Account" name="AccountCondition" type="text"/>
  </div>
END_OF_SCREEN_SECTION
  }

  # Project
  if ($object eq "Transaction" || $object eq "Job")
  {
    print <<END_OF_SCREEN_SECTION;
  <div class="row">
    <label class="rowLabel" for="Project">Project:</label>
    <input maxlength="" size="30" value="" id="Project" name="ProjectCondition" type="text"/>
  </div>
END_OF_SCREEN_SECTION
  }

  # User
  if ($object eq "Transaction" || $object eq "Job")
  {
    print <<END_OF_SCREEN_SECTION;
  <div class="row">
    <label class="rowLabel" for="User">User:</label>
    <input maxlength="" size="30" value="" id="User" name="UserCondition" type="text"/>
  </div>
END_OF_SCREEN_SECTION
  }

  # Machine
  if ($object eq "Transaction" || $object eq "Job")
  {
    print <<END_OF_SCREEN_SECTION;
  <div class="row">
    <label class="rowLabel" for="Machine">Machine:</label>
    <input maxlength="" size="30" value="" id="Machine" name="MachineCondition" type="text"/>
  </div>
END_OF_SCREEN_SECTION
  }

  print <<END_OF_SCREEN_BOTTOM;
  <hr />
  <div id="submitRow">
    <input type="submit" value="Prefilter ${object}s">
  </div>
</form>
END_OF_SCREEN_BOTTOM
}

