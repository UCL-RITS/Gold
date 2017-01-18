#! /usr/bin/perl -wT
################################################################################
#
# Refund Form Frame for Gold Web GUI
#
# File   :  prerefund.cgi
# History:  3 AUG 2005 [Scott Jackson] first implementation
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

        .withdrawOption label{
            font-weight: bold;
        }

-->
END_STYLE_SHEET

# Javascript to changeActivationTable and getValue
my $java_script = <<END_JAVA_SCRIPT;
function submitForm(){
            if(checkRequiredFields()){
                //disable unused fields so that they won't get submitted:
                document.getElementById("Idradio").disabled = true;
                document.getElementById("JobIdradio").disabled = true;
                document.inputForm.submit();
                //put back radio's
                document.getElementById("Idradio").disabled = false;
                document.getElementById("JobIdradio").disabled = false;
            }
}

        function toggleConstraints(){
            var usingId = document.getElementById("Idradio").checked;
            
            if(usingId){
                document.getElementById("Id").disabled = false;
                document.getElementById("JobId").disabled = true;
                
            }else{
                document.getElementById("Id").disabled = true;
                document.getElementById("JobId").disabled = false;
            }
        }
        
        function checkRequiredFields(){
            if(document.getElementById("Id").value == "" && document.getElementById("Idradio").checked){
                alert("Please enter an Id");
                document.getElementById("Id").focus();
                return false;
            }else if(document.getElementById("JobId").value == "" && document.getElementById("JobIdradio").checked){
                alert("Please enter a Job Id");
                document.getElementById("JobId").focus();
                return false;
            }
            return true;
        }
END_JAVA_SCRIPT

# Print the refund form
print header;
print start_html(-title => "Refund Job",
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
    h1("Refund Job") );

  # Print text boxes
  print <<END_OF_SCREEN_TOP;
<p xmlns="" id="requiredDesc">Fields marked with a red asterisk (<span class="required">*</span>) are required.</p>
<form name="inputForm" method="post" action="refund.cgi">
  <input type="hidden" name="myobject" value="$object">
  <input type="hidden" name="myaction" value="$action">
<div class="row">
<label for="Amount" class="rowLabel">Amount:</label>
<input type="text" name="Amount" id="Amount" value="" size="30" maxlength=""/>
</div>
<div class="row">
<label for="Description" class="rowLabel">Description:</label>
<input type="text" name="Description" id="Description" value="" size="30" maxlength=""/>
</div>
<p id="selectInstructions">A Job Id or Gold Job Id must be entered</p>
<div class="row">
<label for="JobId" class="rowLabel">
<span class="required">*</span>Job Id:</label>
<input onkeypress="toggleConstraints()" onclick="toggleConstraints()" checked="true" id="JobIdradio" value="jobId" name="Ids" type="radio"/>
<input id="JobId" name="JobId" size="20" type="text"/>
</div>
<div class="row">
<label for="Id" class="rowLabel">
<span class="required">*</span>Gold Job Id:</label>
<input onkeypress="toggleConstraints()" onclick="toggleConstraints()" id="Idradio" value="id" name="Ids" type="radio"/>
<input disabled="true" id="Id" name="Id" size="20" type="text"/>
</div>
<hr/>
<div id="submitRow">
  <input onClick="submitForm()" value="Refund Job" id="formSubmit" name="refund" type="button"/>
</div>
</form>
END_OF_SCREEN_TOP
}


