#! /usr/bin/perl -wT
################################################################################
#
# Balance Frame for Gold Web GUI
#
# File   :  balance.cgi
# History:  26 JUL 2005 [Scott Jackson] first implementation
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
use lib qw(/opt/gold/dev/lib /opt/gold/dev/lib/perl5);
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
my $user = $cgi->param("User");
my $project = $cgi->param("Project");
my $machine = $cgi->param("Machine");
my $display = $cgi->param("display");
my $showHours = $cgi->param("ShowHours");
my $time_division = $showHours eq "True" ? 3600 : 1;

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

    body {
        background-color: white;
    }
    
    h1 {
        font-size: 110%;
        text-align: center;
    }

    img {
        border-style: none;
    }

    table.sortable a.sortheader {
        background-color: #EFEBAB;
        color: black;
        font-weight: bold;
        text-decoration: none;
        display: block;
        -moz-outline-style: none;
    }
    table.nested {
        padding: 0px;
        margin: 0;
    }

    table.nested td {
        padding: 0px;
        border: 0;
        margin: 0;
    }

    table.sortable {
        border-top: 1px solid black;
        border-left: 1px solid black;
        margin: auto;
        margin-top: 1em;
    }
    table.sortable td {
        border-right: 1px solid black;
        border-bottom: 1px solid black;
        font-size: 70%;
    }

    table.sortable tbody td {
        padding: 6px;
    }

    table.sortable thead td {
        font-weight: bold;
        text-align: center;
        background-color: #EFEBAB;
        white-space: nowrap;
        padding: 6px;
        border: 2px outset;
    }

    table,sortable th div.button {
        border: 1px outset #EFEBAB;
        cursor: default;
    }

    table.sortable th div.button:hover {
        background-color: #FFF9C2;
    }

    table.sortable th div.button:active {
        background-color: #E6E396;
        border-style: inset;
    }

    table.sortable th.deleteHead div, table.sortable th.deleteHead div:hover, table.sortable th.deleteHead div:active {
        background-color: #EFEBAB;
        border-style: solid;
    }

    td.deleteCell, td.modifyCell {
        text-align: center;
        background-color: #FFF9C2;
    }

    #searchForm {
        margin: auto;
        font-size: 75%;
        text-align: center;
    }

    #loadForm {
        text-align: center;
    }

    .sortArrow {
        padding-left: 5px;
    }

    .suggestion_list {
        background: white;
        border: 1px solid;
        padding: 4px;
    }

    .suggestion_list ul {
        padding: 0;
        margin: 0;
        list-style-type: none;
    }

    .suggestion_list a {
        text-decoration: none;
        color: navy;
    }

    .suggestion_list .selected {
        background: navy;
        color: white;
    }
    .suggestion_list .selected a {
        color: white;
    }

    #autosuggest {
        display: none;
    }

-->
END_STYLE_SHEET

print header;
print start_html(-title => "Display Balance",
                 -script => [ { -src => "/cgi-bin/gold/scripts/sorttable.js" } ],
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
    h1("Display Balance") );

  # Print the prebalance form
  print <<END_OF_SCREEN_TOP;
<form name="balanceForm" method="post" action="balance.cgi">
  <input type="hidden" name="myobject" value="$object">
  <input type="hidden" name="myaction" value="$action">
  <input type="hidden" name="display" value="True">
END_OF_SCREEN_TOP

  # Print User Select
  print <<END_OF_SCREEN_SECTION;
  <div style="width: 45em; padding-left: 2.5em;" class="row">
    <div id="MultiUserSelect" class="multiSelect">
      <label class="rowLabel" for="name(./*[1])">Users:</label>
      <select id="User" name="User">
        <option value="">All Users</option>
END_OF_SCREEN_SECTION

  # User Query Special==False
  my $request = new Gold::Request(object => "User", action => "Query", actor => $username);
  $request->setSelection("Name", "Sort");
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
    if ($value eq $user) { $selected = " SELECTED"; }
    print "      <option value=\"$value\"$selected>$value</Option>\n";
  }
  print "      </select>\n    </div>\n";

  # Print Project Select
  print <<END_OF_SCREEN_SECTION;
    <div id="MultiProjectSelect" class="multiSelect">
      <label class="rowLabel" for="name(./*[1])">Projects:</label>
      <select id="Project" name="Project">
        <option value="">All Projects</option>
END_OF_SCREEN_SECTION

  # Project Query Special==False
  my $request = new Gold::Request(object => "Project", action => "Query", actor => $username);
  $request->setSelection("Name", "Sort");
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
    print "      <option value=\"$value\"$selected>$value</Option>\n";
  }
  print "      </select>\n    </div>\n";

  # Print Machine Select
  print <<END_OF_SCREEN_SECTION;
    <div id="MultiMachineSelect" class="multiSelect">
      <label class="rowLabel" for="name(./*[1])">Machines:</label>
      <select id="Machine" name="Machine">
        <option value="">All Machines</option>
END_OF_SCREEN_SECTION

  # Machine Query Special==False
  my $request = new Gold::Request(object => "Machine", action => "Query", actor => $username);
  $request->setSelection("Name", "Sort");
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
    if ($value eq $machine) { $selected = " SELECTED"; }
    print "      <option value=\"$value\"$selected>$value</Option>\n";
  }
  print "      </select>\n    </div>\n  </div>\n";

  print <<END_OF_HOURS_SELECTION;
  <div id="submitRow">
    <label for="ShowHoursYes">Hours</label>
    <input type="radio" name="ShowHours" id="ShowHoursYes" value="True">
    <label for="ShowHoursNo">Seconds</label>
    <input type="radio" name="ShowHours" id="ShowHoursNo" value="False" checked="true">
  </div>
END_OF_HOURS_SELECTION

  print <<END_OF_SCREEN_BOTTOM;
  <div id="submitRow">
    <input type="submit" value="Display Balance">
  </div>
</form>
END_OF_SCREEN_BOTTOM

  if ($display)
  {
    print "<hr/>\n";

    # Account Query Active:=True UseRules:=True User,Project,Machine:=...
    my $request = new Gold::Request(object => "Account", action => "Query", actor => $username);
    $request->setSelection("Id");
    $request->setSelection("Name");
    $request->setOption("Active", "True");
    $request->setOption("UseRules", "True");
    $request->setOption("IncludeAncestors", "True");
    $request->setOption("Project", $project) if $project;
    $request->setOption("User", $user) if $user;
    $request->setOption("Machine", $machine) if $machine;
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
    <table class="sortable" id="accounts" border="0" cellspacing="0">
      <thead>
      <tr>
        <td colspan="1" rowspan="2">Account</td>
        <td colspan="1" rowspan="2">Name</td>
        <td colspan="1" rowspan="2">Amount</td>
        <td colspan="1" rowspan="2">Reserved</td>
        <td colspan="1" rowspan="2">Balance</td>
        <td colspan="1" rowspan="2">Credit Limit</td>
        <td colspan="1" rowspan="2">Available</td>
      </tr>
      <tr>
      </tr>
      </thead>
      <tbody>
END_OF_TABLE

      my %accounts = ();
      my $totalAmount = 0;
      my $totalReserved = 0;
      my $totalCreditLimit = 0;
      my $id = 0;
      foreach my $row (@rows)
      {
        foreach my $col ($row->childNodes())
        {
          my $name = $col->nodeName();
          my $value = $col->textContent(); 
          if ($name eq "Id") { $id = $value; }
          $accounts{$id}{$name} = $value;
        }
      }

      # Extract amount and credit limit from allocations
      my %amount = ();
      my %creditLimit = ();
      {
        # Allocation Query Show:="Sum(Amount),Sum(CreditLimit),GroupBy(Account)"
        # Active==True Account==...
        my $request = new Gold::Request(object => "Allocation", action => "Query", actor => $username);
        $request->setSelection("Account", "GroupBy");
        $request->setSelection("Amount", "Sum");
        $request->setSelection("CreditLimit", "Sum");
        $request->setCondition("Active", "True");
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

        # Iterate over each row of data
        foreach my $row ($data->childNodes())
        {
          my $account = ($row->getChildrenByTagName("Account"))[0]->textContent();
          my $amount = ($row->getChildrenByTagName("Amount"))[0]->textContent();
          my $creditLimit = ($row->getChildrenByTagName("CreditLimit"))[0]->textContent();
          $amount{$account} = $amount;
          $creditLimit{$account} = $creditLimit;
        }
      } 

      # Extract reserved amount from reservation allocations
      my %reserved = ();
      {
        # Reservation,ReservationAllocation Query Show:="Sum(ReservationAllocation.Amount),GroupBy(ReservationAllocation.Account)" Reservation.StartTime<=now Reservation.EndTime>now Reservation.Id==ReservationAllocation.Reservation
        my $request = new Gold::Request(action => "Query", actor => $username);
        $request->setObject("Reservation");
        $request->setObject("ReservationAllocation");
        $request->setSelection(new Gold::Selection(object => "ReservationAllocation", name => "Account", op => "GroupBy"));
        $request->setSelection(new Gold::Selection(object => "ReservationAllocation", name => "Amount", op => "Sum"));
        $request->setCondition(new Gold::Condition(object => "Reservation", name => "Id", subject => "ReservationAllocation", value => "Reservation"));
        $request->setCondition(new Gold::Condition(object => "Reservation", name => "StartTime", op => "LE", value => "now"));
        $request->setCondition(new Gold::Condition(object => "Reservation", name => "EndTime", op => "GT", value => "now"));
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

        # Iterate over each row of data
        foreach my $row ($data->childNodes())
        {
          my $account = ($row->getChildrenByTagName("Account"))[0]->textContent();
          my $reserved = ($row->getChildrenByTagName("Amount"))[0]->textContent();
          $reserved{$account} = $reserved;
        }
      } 

      # Iterate over all accounts
      foreach my $account (sort keys %accounts)
      {
        my $name = $accounts{$account}{"Name"};
        my $amount = $amount{$account}/$time_division || 0;
        my $creditLimit = $creditLimit{$account}/$time_division || 0;
        my $reserved = $reserved{$account}/$time_division || 0;
        my $balance = $amount - $reserved;
        my $available = $balance + $creditLimit;
        $totalAmount += $amount;
        $totalReserved += $reserved;
        $totalCreditLimit += $creditLimit;

        print <<END_OF_TABLE;
      <tr>
        <td>$account</td>
        <td>$name</td>
        <td class="amount">$amount</td>
        <td class="amount">$reserved</td>
        <td class="amount">$balance</td>
        <td class="amount">$creditLimit</td>
        <td class="amount">$available</td>
      </tr>
END_OF_TABLE
      }

      my $totalBalance = $totalAmount-$totalReserved;
      my $totalAvailable = $totalBalance+$totalCreditLimit;

      print <<END_OF_TABLE;
      <tr class="totals">
        <td class="Total" colspan="2">Total:</td>
        <td class="amount">$totalAmount</td>
        <td class="amount">$totalReserved</td>
        <td class="amount">$totalBalance</td>
        <td class="amount">$totalCreditLimit</td>
        <td class="amount">$totalAvailable</td>
      </tr>
      </tbody>
    </table>
END_OF_TABLE
  
    }
  }
}

