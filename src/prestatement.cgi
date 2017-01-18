#! /usr/bin/perl -wT
################################################################################
#
# Statement Form Frame for Gold Web GUI
#
# File   :  prestatement.cgi
# History:  27 JUL 2005 [Scott Jackson] first implementation
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

# Javascript to changeActivationTable and getValue
my $java_script = <<END_JAVA_SCRIPT;
function submitForm(){
  if(document.getElementById('Id').value == "")
    alert("An Account Id must be specified.  Please specify an Account Id and press the Make Account Statement button again.");
  else
    document.inputForm.submit();
}

function newWindow(windowName, url, winWidth, maxHeight) {
    var winHeight = ((screen.availHeight-100) > maxHeight) ? maxHeight : screen.availHeight-100;
                                                                                
    var nw=window.open(url, windowName, "scrollbars,status,resizable,width=" + winWidth + ",height=" + winHeight);
    if(!nw) return null;
                                                                                
    if(parseInt(navigator.appVersion) >= 4) {
        var nwLeft = parseInt((screen.availWidth - winWidth) / 2);
        var nwTop = parseInt((screen.availHeight - winHeight) / 2);                                                                                 
        if(parseInt(navigator.appVersion) >= 4) {
            nw.moveTo(nwLeft, nwTop-50);
        }
    }
    nw.focus();
    return nw;
}

function setId(id){
  document.getElementById('Id').value = id;
}
        
function selectAccount(){
  newWindow('Select Account', 'selectAccount.cgi', 750, 500);
}

END_JAVA_SCRIPT

# Print the statement form
print header;
print start_html(-title => "Account Statement",
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
    h1("Account Statement") );

  # Print text boxes
  print <<END_OF_SCREEN_TOP;
<p xmlns="" id="requiredDesc">Fields marked with a red asterisk (<span class="required">*</span>) are required.</p>
<form name="inputForm" method="post" action="statement.cgi">
  <input type="hidden" name="myobject" value="$object">
  <input type="hidden" name="myaction" value="$action">
  <div class="row">
    <label for="Id" class="rowLabel">
    <span class="required">*</span>Account Id:</label>
    <input type="text" name="Id" id="Id" value="" size="30" maxlength=""/>
    <input type="button" name="selectAccountButton" id="selectAccountButton" value="Select..." onClick="selectAccount()"/>
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
    <strong class="rowLabel">Itemize?</strong><input type="radio" name="Itemize" id="ItemizeYes" value="True" checked="true"><label for="ItemizeYes">Yes</label><input type="radio" name="Itemize" id="ItemizeNo" value="False"><label for="ItemizeNo">No</label>
  </div>
  <hr/>
  <div id="submitRow">
    <input onClick="submitForm()" value="Account Statement" id="formSubmit" name="statement" type="button"/>
  </div>
</form>
END_OF_SCREEN_TOP
}


