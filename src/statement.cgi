#! /usr/bin/perl -wT
################################################################################
#
# Statement Frame for Gold Web GUI
#
# File   :  statement.cgi
# History:  29 JUL 2005 [Scott Jackson] first implementation
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

my $cgi      = new CGI;
my $session  = new CGI::Session(undef, $cgi, {Directory => "/tmp"});
my $username = $session->param("username");
my $password = $session->param("password");
unless ($username && $password)
{
    print header;
    print start_html(
        -title  => "Session Expired",
        -onLoad => "top.location.replace(\"login.cgi\");"
    );
    print end_html;
    exit(0);
}

my $object        = $cgi->param("myobject");
my $action        = $cgi->param("myaction");
my $account       = $cgi->param("Account");
my $project       = $cgi->param("Project");
my $user          = $cgi->param("User");
my $machine       = $cgi->param("Machine");
my $startTime     = $cgi->param("StartTime");
my $endTime       = $cgi->param("EndTime");
my $itemize       = $cgi->param("Itemize");
my $showHours     = $cgi->param("ShowHours");
my $display       = $cgi->param("display");
my $time_division = $showHours eq "True" ? 3600 : 1;
my $currency_precision =
  $showHours eq "True" ? 2 : $config->get_property("currency.precision") || 0;

if ($currency_precision =~ /^(\d+)$/)
{
    $currency_precision = $1;
}
else
{
    die
      "Illegal characters were found in \$currency_precision ($currency_precision)\n";
}

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

# Javascript to changeActivationTable and getValue
my $java_script = <<END_JAVA_SCRIPT;
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
  document.getElementById('Account').value = id;
}
                                                                                
function selectAccount(){
  newWindow('Select Account', 'selectAccount.cgi', 750, 500);
}
                                                                                
function updateStatus(statusInfo) {
  if (statusInfo) {
    parent.statusbar.document.location="status.cgi?" + statusInfo;
    document.resultsForm.submit();
  }
}

END_JAVA_SCRIPT

print header;
print start_html(
    -title  => "Account Statement",
    -script => {-code => $java_script},
    -style  => {-code => $style_sheet},
);
print_body();
print end_html;

sub print_body
{
    # Print the header
    print div(
        {-class => "header"},
        div(
            {-class => "leftFlare"},
            img(
                {
                    -alt    => "",
                    -height => "36",
                    -width  => "16",
                    -src    => "/cgi-bin/gold/images/header_flare_left.gif"
                }
            )
        ),
        div(
            {-class => "rightFlare"},
            img(
                {
                    -alt    => "",
                    -height => "36",
                    -width  => "16",
                    -src    => "/cgi-bin/gold/images/header_flare_right.gif"
                }
            )
        ),
        h1("Account Statement")
    );

    # Print the usage form
    print <<END_OF_SCREEN_TOP;
<form name="inputForm" method="post" action="statement.cgi">
  <input type="hidden" name="myobject" value="$object">
  <input type="hidden" name="myaction" value="$action">
  <input type="hidden" name="display" value="True">
  <div class="row">
    <label for="Account" class="rowLabel">Account Id:</label>
    <input type="text" name="Account" id="Account" value="" size="30" maxlength=""/>
    <input type="button" name="selectAccountButton" id="selectAccountButton" value="Select..." onClick="selectAccount()"/>
  </div>
END_OF_SCREEN_TOP

    # Print Project Select
    {
        print <<END_OF_SCREEN_SECTION;
    <div class="row">
      <div id="MultiProjectSelect" class="multiSelect">
        <label class="rowLabel" for="name(./*[1])">Projects:</label>
        <select id="Project" name="Project">
          <option value="">All Projects</option>
END_OF_SCREEN_SECTION

        # Project Query Special==False
        my $request = new Gold::Request(
            object => "Project",
            action => "Query",
            actor  => $username
        );
        $request->setSelection("Name");
        $request->setCondition("Special", "False");
        my $messageChunk = new Gold::Chunk(
            tokenType  => $TOKEN_PASSWORD,
            tokenName  => $username,
            tokenValue => "$password"
        );
        $messageChunk->setRequest($request);
        my $replyChunk = $messageChunk->getChunk();
        my $response   = $replyChunk->getResponse();
        my $status     = $response->getStatus();
        my $message    = $response->getMessage();
        my $data       = $response->getDataElement();
        my $count      = $response->getCount();
        my $doc        = XML::LibXML::Document->new();
        $doc->setDocumentElement($data);

        foreach my $row ($data->childNodes())
        {
            my $value = ($row->childNodes())[0]->textContent();
            print "        <option value=\"$value\">$value</Option>\n";
        }

        print <<END_OF_SCREEN;
    </select>
    </div>
  </div
END_OF_SCREEN
    }

    # Print User Select
    {
        print <<END_OF_SCREEN_SECTION;
    <div class="row">
      <div id="MultiUserSelect" class="multiSelect">
        <label class="rowLabel" for="name(./*[1])">Users:</label>
        <select id="User" name="User">
          <option value="">All Users</option>
END_OF_SCREEN_SECTION

        # User Query Special==False
        my $request = new Gold::Request(
            object => "User",
            action => "Query",
            actor  => $username
        );
        $request->setSelection("Name");
        $request->setCondition("Special", "False");
        my $messageChunk = new Gold::Chunk(
            tokenType  => $TOKEN_PASSWORD,
            tokenName  => $username,
            tokenValue => "$password"
        );
        $messageChunk->setRequest($request);
        my $replyChunk = $messageChunk->getChunk();
        my $response   = $replyChunk->getResponse();
        my $status     = $response->getStatus();
        my $message    = $response->getMessage();
        my $data       = $response->getDataElement();
        my $count      = $response->getCount();
        my $doc        = XML::LibXML::Document->new();
        $doc->setDocumentElement($data);

        foreach my $row ($data->childNodes())
        {
            my $value = ($row->childNodes())[0]->textContent();
            print "        <option value=\"$value\">$value</Option>\n";
        }

        print <<END_OF_SCREEN;
    </select>
    </div>
  </div
END_OF_SCREEN
    }

    # Print Machine Select
    {
        print <<END_OF_SCREEN_SECTION;
    <div class="row">
      <div id="MultiMachineSelect" class="multiSelect">
        <label class="rowLabel" for="name(./*[1])">Machines:</label>
        <select id="Machine" name="Machine">
          <option value="">All Machines</option>
END_OF_SCREEN_SECTION

        # Machine Query Special==False
        my $request = new Gold::Request(
            object => "Machine",
            action => "Query",
            actor  => $username
        );
        $request->setSelection("Name");
        $request->setCondition("Special", "False");
        my $messageChunk = new Gold::Chunk(
            tokenType  => $TOKEN_PASSWORD,
            tokenName  => $username,
            tokenValue => "$password"
        );
        $messageChunk->setRequest($request);
        my $replyChunk = $messageChunk->getChunk();
        my $response   = $replyChunk->getResponse();
        my $status     = $response->getStatus();
        my $message    = $response->getMessage();
        my $data       = $response->getDataElement();
        my $count      = $response->getCount();
        my $doc        = XML::LibXML::Document->new();
        $doc->setDocumentElement($data);

        foreach my $row ($data->childNodes())
        {
            my $value = ($row->childNodes())[0]->textContent();
            print "        <option value=\"$value\">$value</Option>\n";
        }

        print <<END_OF_SCREEN;
    </select>
    </div>
  </div
END_OF_SCREEN
    }

    print <<END_OF_SCREEN;
  <div class="row">
    <label for="StartTime" class="rowLabel">Start Date:</label>
    <input type="text" name="StartTime" id="StartTime" value="" size="30" maxlength=""/>
  </div>
  <div class="row">
    <label for="EndTime" class="rowLabel">End Date:</label>
    <input type="text" name="EndTime" id="EndTime" value="" size="30" maxlength=""/>
  </div>
  <div class="row">
    <strong class="rowLabel">Itemize?</strong><input type="radio" name="Itemize" id="ItemizeYes" value="True"><label for="ItemizeYes">Yes</label><input type="radio" name="Itemize" id="ItemizeNo" value="False" checked="true"><label for="ItemizeNo">No</label>
  </div>
  <div class="row">
    <strong class="rowLabel">Show Hours?</strong><input type="radio" name="ShowHours" id="ShowHoursYes" value="True"><label for="ShowHoursYes">Yes</label><input type="radio" name="ShowHours" id="ShowHoursNo" value="False" checked="true"><label for="ShowHoursNo">No</label>
  </div>
  <div id="submitRow">
    <input value="Display Statement" type="submit"/>
  </div>
</form>
END_OF_SCREEN

    if ($display)
    {
        my %accounts = ();

        print "<hr/>\n";

        unless ($startTime) { $startTime = "-infinity"; }
        unless ($endTime)   { $endTime   = "now"; }

        # Obtain list of applicable accounts
        {
        # Account Query Show:="Sort(Id),Name" [Id:=$account] [Project:=$project]
        # [User:=$user] [Machine:=$machine] UseRules:=True
            my $request = new Gold::Request(
                object => "Account",
                action => "Query",
                actor  => $username
            );
            $request->setSelection("Id", "Sort");
            $request->setSelection("Name");
            $request->setCondition("Id", $account) if $account;
            $request->setOption("Project", $project) if $project;
            $request->setOption("User",    $user)    if $user;
            $request->setOption("Machine", $machine) if $machine;
            $request->setOption("UseRules", "True");
            my $messageChunk = new Gold::Chunk(
                tokenType  => $TOKEN_PASSWORD,
                tokenName  => $username,
                tokenValue => "$password"
            );
            $messageChunk->setRequest($request);
            my $replyChunk = $messageChunk->getChunk();
            my $response   = $replyChunk->getResponse();
            my $status     = $response->getStatus();
            my $message    = $response->getMessage();
            my @data       = $response->getData();

            foreach my $datum (@data)
            {
                $accounts{$datum->getValue("Id")} = $datum->getValue("Name");
            }
            if (scalar keys %accounts == 0)
            {
                # Display an error message
                print end_html;
                print start_html(
                    -title  => "Gold Error",
                    -script => {-code => $java_script},
                    -onLoad =>
                      "updateStatus(\"message=No accounts were matched. An account statement cannot be produced for the chosen selections.\")"
                );
                return;
            }
        }

        print "<div id=\"available\">\n";
        print
          "<strong>Statement for account $account ($accounts{$account})</strong><br>\n"
          if $account;
        print "<strong>Statement for project $project</strong><br>\n"
          if $project;
        print "<strong>Statement for user $user</strong><br>\n" if $user;
        print "<strong>Statement for machine $machine</strong><br>\n"
          if $machine;
        if (! $account)
        {

            foreach my $id (sort keys %accounts)
            {
                print
                  "<strong>Includes account $id ($accounts{$id})</strong><br>\n";
            }
        }
        print
          "<strong>Reporting account activity from $startTime to $endTime</strong><br>\n";
        print "<br>\n";

        # Add up the beginning active allocations
        my $beginningBalance = 0;
        {
            my $request = new Gold::Request(
                object => "Allocation",
                action => "Query",
                actor  => $username
            );
            setAccounts($request, \%accounts);
            $request->setCondition("Active", "True");
            $request->setOption("Time", $startTime);
            $request->setSelection("Amount", "Sum");
            my $messageChunk = new Gold::Chunk(
                tokenType  => $TOKEN_PASSWORD,
                tokenName  => $username,
                tokenValue => "$password"
            );
            $messageChunk->setRequest($request);
            my $replyChunk = $messageChunk->getChunk();
            my $response   = $replyChunk->getResponse();

            if ($response->getStatus() eq "Failure")
            {
                my $code    = $response->getCode();
                my $message = $response->getMessage();
                print start_html(
                    -title  => "Gold Error",
                    -script => {-code => $java_script},
                    -onLoad =>
                      "updateStatus(\"message=Aborting Account Statement: $message.\")"
                );
                return;
            }
            my $doc  = XML::LibXML::Document->new();
            my $data = $response->getDataElement();
            $doc->setDocumentElement($data);
            foreach my $row ($data->childNodes())
            {
                my $sum =
                  ($row->getChildrenByTagName("Amount"))[0]->textContent();
                $beginningBalance += $sum if $sum;
            }
        }

        # Print the beginning balance
        printf(
            "<strong>Beginning Balance:</strong> %20.${currency_precision}f<br>\n",
            $beginningBalance / $time_division);

        # Obtain the sum of all credits over the time period
        my $totalCredits = 0;
        {
            my $request = new Gold::Request(
                object => "Transaction",
                action => "Query",
                actor  => $username
            );
            setAccounts($request, \%accounts);
            $request->setCondition("Delta",        0,          "GT");
            $request->setCondition("CreationTime", $startTime, "GE");
            $request->setCondition("CreationTime", $endTime,   "LT");
            $request->setSelection("Delta", "Sum");
            my $messageChunk = new Gold::Chunk(
                tokenType  => $TOKEN_PASSWORD,
                tokenName  => $username,
                tokenValue => "$password"
            );
            $messageChunk->setRequest($request);
            my $replyChunk = $messageChunk->getChunk();
            my $response   = $replyChunk->getResponse();

            if ($response->getStatus() eq "Failure")
            {
                my $code    = $response->getCode();
                my $message = $response->getMessage();
                print start_html(
                    -title  => "Gold Error",
                    -script => {-code => $java_script},
                    -onLoad =>
                      "updateStatus(\"message=Aborting Account Statement: $message.\")"
                );
                return;
            }
            my $doc  = XML::LibXML::Document->new();
            my $data = $response->getDataElement();
            $doc->setDocumentElement($data);
            foreach my $row ($data->childNodes())
            {
                my $sum =
                  ($row->getChildrenByTagName("Delta"))[0]->textContent();
                $totalCredits += $sum if $sum;
            }
        }

        # Print the total credits
        printf(
            "<strong>Total Credits:</strong>     %20.${currency_precision}f<br>\n",
            $totalCredits / $time_division);

        # Obtain the sum of all debits over the time period
        my $totalDebits = 0;
        {
            my $request = new Gold::Request(
                object => "Transaction",
                action => "Query",
                actor  => $username
            );
            setAccounts($request, \%accounts);
            $request->setCondition("Delta",        0,          "LE");
            $request->setCondition("CreationTime", $startTime, "GE");
            $request->setCondition("CreationTime", $endTime,   "LT");
            $request->setSelection("Delta", "Sum");
            my $messageChunk = new Gold::Chunk(
                tokenType  => $TOKEN_PASSWORD,
                tokenName  => $username,
                tokenValue => "$password"
            );
            $messageChunk->setRequest($request);
            my $replyChunk = $messageChunk->getChunk();
            my $response   = $replyChunk->getResponse();

            if ($response->getStatus() eq "Failure")
            {
                my $code    = $response->getCode();
                my $message = $response->getMessage();
                print start_html(
                    -title  => "Gold Error",
                    -script => {-code => $java_script},
                    -onLoad =>
                      "updateStatus(\"message=Aborting Account Statement: $message.\")"
                );
                return;
            }
            my $doc  = XML::LibXML::Document->new();
            my $data = $response->getDataElement();
            $doc->setDocumentElement($data);
            foreach my $row ($data->childNodes())
            {
                my $sum =
                  ($row->getChildrenByTagName("Delta"))[0]->textContent();
                $totalDebits += $sum if $sum;
            }
        }

        # Print the total debits
        printf(
            "<strong>Total Debits:</strong>      %20.${currency_precision}f<br>\n",
            $totalDebits / $time_division);

        # Add up the ending active allocations
        my $endingBalance = 0;
        {
            my $request = new Gold::Request(
                object => "Allocation",
                action => "Query",
                actor  => $username
            );
            setAccounts($request, \%accounts);
            $request->setCondition("Active", "True");
            $request->setOption("Time", $endTime);
            $request->setSelection("Amount", "Sum");
            my $messageChunk = new Gold::Chunk(
                tokenType  => $TOKEN_PASSWORD,
                tokenName  => $username,
                tokenValue => "$password"
            );
            $messageChunk->setRequest($request);
            my $replyChunk = $messageChunk->getChunk();
            my $response   = $replyChunk->getResponse();

            if ($response->getStatus() eq "Failure")
            {
                my $code    = $response->getCode();
                my $message = $response->getMessage();
                print start_html(
                    -title  => "Gold Error",
                    -script => {-code => $java_script},
                    -onLoad =>
                      "updateStatus(\"message=Aborting Account Statement: $message.\")"
                );
                return;
            }
            my $doc  = XML::LibXML::Document->new();
            my $data = $response->getDataElement();
            $doc->setDocumentElement($data);
            foreach my $row ($data->childNodes())
            {
                my $sum =
                  ($row->getChildrenByTagName("Amount"))[0]->textContent();
                $endingBalance += $sum if $sum;
            }
        }

        # Print the ending balance
        printf(
            "<strong>Ending Balance:</strong>    %20.${currency_precision}f<br>\n",
            $endingBalance / $time_division);

        # Check for transactional consistency with journal state
        my $discrepancy =
          ($totalCredits + $totalDebits) - ($endingBalance - $beginningBalance);
        if ($discrepancy)
        {
            printf
              "<br><strong>Warning: A discrepancy of %20d credits was detected\nbetween the logged transactions and the historical account balances.</strong><br>\n",
              $discrepancy;
        }

        print "</div>\n";
        print "<hr>\n";

        # Print credit and debit detail (or summary)
        {
            my $detail;
            if   ($itemize eq "True") { $detail = "Detail"; }
            else                      { $detail = "Summary"; }

            print <<END_OF_SCREEN;
<div id="available">
<strong>Credit $detail:</strong>
</div>
END_OF_SCREEN

            # Print out all of the credits
            {
                my $total = 0;
                my $colspan;

                my $request = new Gold::Request(
                    object => "Transaction",
                    action => "Query",
                    actor  => $username
                );
                setAccounts($request, \%accounts);
                $request->setCondition("Delta",        0,          "GT");
                $request->setCondition("CreationTime", $startTime, "GE");
                $request->setCondition("CreationTime", $endTime,   "LT");
                if ($itemize eq "True")
                {
                    $request->setSelection("Object");
                    $request->setSelection("Action");
                    $request->setSelection("JobId");
                    $request->setSelection("CreationTime", "Sort", "", "Time");
                    $request->setSelection("Delta", "", "", "Amount");
                    $colspan = 4;
                }
                else
                {
                    $request->setSelection("Object", "GroupBy");
                    $request->setSelection("Action", "GroupBy");
                    $request->setSelection("Delta",  "Sum", "", "Amount");
                    $colspan = 2;
                }
                my $messageChunk = new Gold::Chunk(
                    tokenType  => $TOKEN_PASSWORD,
                    tokenName  => $username,
                    tokenValue => "$password"
                );
                $messageChunk->setRequest($request);
                my $replyChunk = $messageChunk->getChunk();
                my $response   = $replyChunk->getResponse();
                if ($response->getStatus() eq "Failure")
                {
                    my $code    = $response->getCode();
                    my $message = $response->getMessage();
                    print start_html(
                        -title  => "Gold Error",
                        -script => {-code => $java_script},
                        -onLoad =>
                          "updateStatus(\"message=Aborting Account Statement: $message.\")"
                    );
                    return;
                }
                my $data = $response->getDataElement();
                my $doc  = XML::LibXML::Document->new();
                $doc->setDocumentElement($data);
                my @rows = $data->childNodes();

                if (@rows > 0)
                {
                    # Print Table Header
                    print <<END_OF_SCREEN;
<table id="accounts" cellspacing="0">
  <tr>
END_OF_SCREEN
                    foreach my $col (($rows[0])->childNodes())
                    {
                        my $name = $col->nodeName();
                        print "<th><div>$name</div></th>\n";
                    }
                    print "</tr>\n";

                    # Print Table Body
                    foreach my $row (@rows)
                    {
                        print "<tr>\n";
                        foreach my $col ($row->childNodes())
                        {
                            my $name  = $col->nodeName();
                            my $value = $col->textContent();
                            if ($name eq "Amount")
                            {
                                $value = sprintf("%.${currency_precision}f",
                                    $value / $time_division);
                                $total += $value;
                            }
                            $value = "&nbsp;"
                              if $value eq "";    # So border will be drawn
                            print "<td>$value</td>\n";
                        }
                        print "</tr>\n";
                    }

                    # Print Table Totals
                    print <<END_OF_SCREEN;
<tr class="totals">
<td class="Total" colspan="$colspan">Total:</td><td class="amount">$total</td>
</tr>
</table>
END_OF_SCREEN
                }
            }

            print <<END_OF_SCREEN;
<div id="available">
<strong>Debit $detail:</strong>
</div>
END_OF_SCREEN

            # Print out all of the debits
            {
                my $total = 0;
                my $colspan;

                my $request = new Gold::Request(
                    object => "Transaction",
                    action => "Query",
                    actor  => $username
                );
                setAccounts($request, \%accounts);
                $request->setCondition("Delta",        0,          "LE");
                $request->setCondition("CreationTime", $startTime, "GE");
                $request->setCondition("CreationTime", $endTime,   "LT");
                if ($itemize eq "True")
                {
                    $request->setSelection("Object");
                    $request->setSelection("Action");
                    $request->setSelection("JobId");
                    $request->setSelection("Project");
                    $request->setSelection("User");
                    $request->setSelection("Machine");
                    $request->setSelection("CreationTime", "Sort", "", "Time");
                    $request->setSelection("Delta", "", "", "Amount");
                    $colspan = 7;
                }
                else
                {
                    $request->setSelection("Object",  "GroupBy");
                    $request->setSelection("Action",  "GroupBy");
                    $request->setSelection("Project", "GroupBy");
                    $request->setSelection("User",    "GroupBy");
                    $request->setSelection("Machine", "GroupBy");
                    $request->setSelection("Delta",   "Sum", "", "Amount");
                    $colspan = 5;
                }
                my $messageChunk = new Gold::Chunk(
                    tokenType  => $TOKEN_PASSWORD,
                    tokenName  => $username,
                    tokenValue => "$password"
                );
                $messageChunk->setRequest($request);
                my $replyChunk = $messageChunk->getChunk();
                my $response   = $replyChunk->getResponse();
                if ($response->getStatus() eq "Failure")
                {
                    my $code    = $response->getCode();
                    my $message = $response->getMessage();
                    print start_html(
                        -title  => "Gold Error",
                        -script => {-code => $java_script},
                        -onLoad =>
                          "updateStatus(\"message=Aborting Account Statement: $message.\")"
                    );
                    return;
                }
                my $data = $response->getDataElement();
                my $doc  = XML::LibXML::Document->new();
                $doc->setDocumentElement($data);
                my @rows = $data->childNodes();

                if (@rows > 0)
                {
                    # Print Table Header
                    print <<END_OF_SCREEN;
<table id="accounts" cellspacing="0">
  <tr>
END_OF_SCREEN
                    foreach my $col (($rows[0])->childNodes())
                    {
                        my $name = $col->nodeName();
                        print "<th><div>$name</div></th>\n";
                    }
                    print "</tr>\n";

                    # Print Table Body
                    foreach my $row (@rows)
                    {
                        print "<tr>\n";
                        foreach my $col ($row->childNodes())
                        {
                            my $name  = $col->nodeName();
                            my $value = $col->textContent();
                            if ($name eq "Amount")
                            {
                                $value = sprintf("%.${currency_precision}f",
                                    $value / $time_division);
                                $total += $value;
                            }
                            $value = "&nbsp;"
                              if $value eq "";    # So border will be drawn
                            print "<td>$value</td>\n";
                        }
                        print "</tr>\n";
                    }

                    # Print Table Totals
                    print <<END_OF_SCREEN;
<tr class="totals">
<td class="Total" colspan="$colspan">Total:</td><td class="amount">$total</td>
</tr>
</table>
END_OF_SCREEN
                }
            }
        }
        print "<hr>\n";
    }
}

# Subroutine that builds the conditions list for multiple accounts
sub setAccounts
{
    my ($request, $accounts_hashref) = @_;

    my @accounts = keys %{$accounts_hashref};
    my $count    = 0;
    my $total    = scalar @accounts;

    foreach my $account (@accounts)
    {
        my ($conj, $group);

        $count++;
        if ($count == 1)
        {
            $conj = "And";
            if   ($count == $total) { $group = "0"; }
            else                    { $group = "+1"; }
        }
        else
        {
            $conj = "Or";
            if   ($count == $total) { $group = "-1"; }
            else                    { $group = "0"; }
        }
        $request->setCondition("Account", $account, "EQ", $conj, $group);
    }
}

