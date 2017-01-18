#! /usr/bin/perl -wT
################################################################################
#
# Charge Form Frame for Gold Web GUI
#
# File   :  precharge.cgi
# History:  1 AUG 2005 [Scott Jackson] first implementation
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
my $attributes_ref = $session->param("attributes");
my %attributes = %{$attributes_ref};

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

-->
END_STYLE_SHEET

# Javascript to changeActivationTable and getValue
my $java_script = <<END_JAVA_SCRIPT;
function submitForm(){
  if(document.getElementById('JobId').value == "")
    alert("A Job Id must be specified.  Please specify a Job Id and press the Charge Job button again.");
  else
    document.inputForm.submit();
}

END_JAVA_SCRIPT

# Print the create form
print header;
print start_html(-title => "Charge Job",
                 -script => { -code => $java_script },
                 -style => { -code => $style_sheet },
);
print_body();
print end_html;

sub print_body
{
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
    h1("Charge Job") );

  # Obtain a list of all job attributes
  my @names = ();
  my %required = ();
  my %fixed = ();
  my %dataTypes = ();
  my %values = ();
  my %descriptions = ();
  foreach my $name (sort { $attributes{$object}{$a}{Sequence} <=> $attributes{$object}{$b}{Sequence} } keys %{$attributes{$object}})
  {
    my $hidden = $attributes{$object}{$name}{Hidden};
    my $required = $attributes{$object}{$name}{Required};
    my $fixed = $attributes{$object}{$name}{Fixed};
    my $dataType = $attributes{$object}{$name}{DataType};
    my $values = $attributes{$object}{$name}{Values};
    my $defaultValue = $attributes{$object}{$name}{DefaultValue};
    my $description = $attributes{$object}{$name}{Description};
                                                                                
    next if $hidden eq "True";
    next if $dataType eq "AutoGen";
    push @names, $name;
    $required{$name} = $required;
    $fixed{$name} = $fixed;
    $dataTypes{$name} = $dataType;
    $values{$name} = $values;
    $descriptions{$name} = $description;
  }

  # Print text boxes
  print <<END_OF_SCREEN_TOP;
<p xmlns="" id="requiredDesc">Fields marked with a red asterisk (<span class="required">*</span>) are required.</p>
<form xmlns="" name="inputForm" method="post" action="charge.cgi">
  <input type="hidden" name="myobject" value="$object">
  <input type="hidden" name="myaction" value="$action">
  <div class="row">
    <label for="JobId" class="rowLabel">
    <span class="required">*</span>Job Id:</label>
    <input type="text" name="JobIdOption" id="JobId" value="" size="30" maxlength=""/>
  </div>
  <div class="row">
    <label for="User" class="rowLabel">User Name:</label>
    <input type="text" name="UserOption" id="User" value="" size="30" maxlength=""/>
  </div>
  <div class="row">
    <label for="Project" class="rowLabel">Project Name:</label>
    <input type="text" name="ProjectOption" id="Project" value="" size="30" maxlength=""/>
  </div>
  <div class="row">
    <label for="Machine" class="rowLabel">Machine Name:</label>
    <input type="text" name="MachineOption" id="Machine" value="" size="30" maxlength=""/>
  </div>
  <div class="row">
    <label for="WallDuration" class="rowLabel">Wallclock Time:</label>
    <input type="text" name="WallDurationOption" id="WallDuration" value="" size="30" maxlength=""/>
  </div>

  <div class="row">
    <label for="Allocation" class="rowLabel">Allocation Id:</label>
    <input type="text" name="Allocation" id="Allocation" value="" size="30" maxlength=""/>
  </div>
  <div class="row">
    <label for="StartTime" class="rowLabel">Start Date:</label>
    <input type="text" name="StartTime" id="StartTime" value="" size="30" maxlength=""/>
  </div>
  <div class="row">
    <label for="EndTime" class="rowLabel">End Date:</label>
    <input type="text" name="EndTime" id="EndTime" value="" size="30" maxlength=""/>
  </div>
  <div class="row">
    <label for="Description" class="rowLabel">Description:</label>
    <input type="text" name="Description" id="Description" value="" size="30" maxlength=""/>
  </div>
  <hr/>
  <div id="submitRow">
    <input onClick="submitForm()" value="Make Deposit" id="formSubmit" name="deposit" type="button"/>
  </div>
</form>
END_OF_SCREEN_TOP
}


