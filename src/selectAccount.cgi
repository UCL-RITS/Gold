#! /usr/bin/perl -wT
################################################################################
#
# Select Account Pane for Gold Web GUI
# This is used to list the accounts for Account actions
# such as Deposit, Withdraw, Transfer, etc.
#
# File   :  selectAccount.cgi
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

my $objects_ref = $session->param("objects");
my %objects = %{$objects_ref};
my $actions_ref = $session->param("actions");
my %actions = %{$actions_ref};
my $attributes_ref = $session->param("attributes");
my %attributes = %{$attributes_ref};
my $object = "Account";
my $action = "Query";
my @columnInfo = ();

# Sort subroutine for association names

my %association_precedence = (
  "AccountProject" => -8,
  "AccountUser" => -7,
  "AccountMachine" => -6,
  "AccountAccount" => -5,
  "ProjectUser" => -4,
  "ProjectMachine" => -3,
  "RoleAction" => -2,
  "RoleUser" => -1,
);
                                                                                
sub by_association
{
  return ((defined($association_precedence{$a})?$association_precedence{$a}:0) <=> (defined($association_precedence{$b})?$association_precedence{$b}:0)) || ($a cmp $b);
}

# Sort subroutine for association children

my %field_precedence = (
  "Object" => -16,
  "Type" => -15,
  "Id" => -14,
  "Name" => -13,
  "Active" => -12,
  "Admin" => -11,
  "Access" => -10,
  "Instance" => -9,
  "DepositShare" => -8,
  "Overflow" => -7,
  "Rate" => -6,
  "User" => -5,
  "Project" => -4,
  "Machine" => -3,
  "Account" => -2,
  "Amount" => -1,
);
                                                                                
sub by_field
{
  return ((defined($field_precedence{$a})?$field_precedence{$a}:0) <=> (defined($field_precedence{$b})?$field_precedence{$b}:0)) || ($a cmp $b);
}

# Initial Javascript section to define updateStatus for errors
my $java_script = <<END_JAVA_SCRIPT;
  var searchValues = new Array();

  function updateStatus(statusInfo) {
    if (statusInfo)
    {
      parent.statusbar.document.location="status.cgi?" + statusInfo;
    }
  }

function selectAccount(id){
            window.opener.setId(id);
            window.close();
        }
END_JAVA_SCRIPT

# Derive primary keys from %attributes
my @primaryKeys = ();
foreach my $name (keys %{$attributes{$object}})
{
  if ($attributes{$object}{$name}{"PrimaryKey"} eq "True")
  {
    push @primaryKeys, $name;
    last;
  }
}

# Build the primary object query
my $request = new Gold::Request(object => $object, action => "Query", actor => $username);

# Issue the Query
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

# On success, add member data to response
if ($status ne "Failure")
{
  my %members;
  my %amount;

  # Build up column info for the simple data
  my @rows = $data->childNodes();
  if (@rows > 0)
  {
    my $count = 0;
    foreach my $col ($rows[0]->childNodes())
    {
      my $name = $col->nodeName();
      $columnInfo[$count]{"Name"} = $name;
      $columnInfo[$count]{"Fields"} = {};
      $count++;
    }
  }

  # Iterate through data appending a column containing the appropriate pk
  foreach my $row (@rows)
  {
    my @conditions = ();
    my $actionCol = new XML::LibXML::Element("_${action}");
    foreach my $col ($row->childNodes())
    {
      my $name = $col->nodeName();
      my $value = $col->textContent();
      if (grep($_ eq $name, @primaryKeys))
      {
        push @conditions, "$name=$value";
      }
    }
    $actionCol->appendText(join ',', @conditions);
    $row->appendChild($actionCol);
  }

  # Build up a list of associations from %objects
  my @associations = ();
  foreach my $name (sort keys %objects)
  {
    if ($objects{$name}{"Association"} eq "True" && $objects{$name}{"Parent"} eq $object && $actions{$name}{"Query"}{"Display"} eq "True")
    {
      push @associations, $name;
    }
  }

  # Iterate over all associations, merging in data
  foreach my $association (sort by_association @associations)
  {
    my $child = $objects{$association}{"Child"} . "s";

    my $request = new Gold::Request(object => $association, action => "Query", actor => $username);
    if ($action eq "Undelete") { $request->setCondition("Deleted", "True"); }
    my $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
    $messageChunk->setRequest($request);
    my $replyChunk = $messageChunk->getChunk();
    my $response = $replyChunk->getResponse();
    my $status = $response->getStatus();
    my $message = $response->getMessage();
    my $subData = $response->getDataElement();
    my $subDoc = XML::LibXML::Document->new();
    $subDoc->setDocumentElement($subData);

    if ($status ne "Failure")
    {
      my @rows = $subData->childNodes();
      if (@rows > 0)
      {
        # Build up column info for the structured (association) data
        my $newCol = $#columnInfo + 1;
        $columnInfo[$newCol]{"Name"} = $child;

        # Add association data to the hash:
        # $members{$parent}{$child}[$row]{$propertyName} = $propertyValue
        foreach my $row (@rows)
        {
          my %properties = ();
          my $parent = ($row->getChildrenByTagName($object))[0]->textContent();
          foreach my $col ($row->childNodes())
          {
            my $name = $col->nodeName();
            $columnInfo[$newCol]{"Fields"}{$name} ||= 1;
            next if $name eq $object; # Exclude parent foreign key
            my $value = $col->textContent();
            # This needs to be corrected to include an array of KVPs
            $properties{$name} = $value;
          }
          push @{$members{$parent}{$child}}, \%properties;
        }
      }
    }
    else
    {
      # Just display error message
      print end_html;
      print header;
      print start_html(-title => "Gold Error",
                       -script => { -code => $java_script },
                       -onLoad => "updateStatus(\"message=$message\")"
        );
      print end_html;
      exit 0;
    }
  }

  # Populate amount info from allocations if object equals account
  if ($object eq "Account" && exists $objects{"Allocation"})
  {
    my $request = new Gold::Request(object => "Allocation", action => "Query", actor => $username);
    if ($action eq "Undelete") { $request->setCondition("Deleted", "True"); }
    $request->setSelection("Amount", "Sum");
    $request->setSelection("Account", "GroupBy");
    $request->setCondition("Active", "True");
    my $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
    $messageChunk->setRequest($request);
    my $replyChunk = $messageChunk->getChunk();
    my $response = $replyChunk->getResponse();
    my $status = $response->getStatus();
    my $message = $response->getMessage();
    my $subData = $response->getDataElement();
    my $subDoc = XML::LibXML::Document->new();
    $subDoc->setDocumentElement($subData);

    if ($status ne "Failure")
    {
      my @rows = $subData->childNodes();
      if (@rows > 0)
      {
        # Build up column info for the allocation amount
        my $newCol = $#columnInfo + 1;
        $columnInfo[$newCol]{"Name"} = "Amount";
        $columnInfo[$newCol]{"Fields"} = {};

        # Add amount data to the hash:
        # $amount{$account} = $amount
        foreach my $row (@rows)
        {
          my $account = ($row->getChildrenByTagName("Account"))[0]->textContent();
          my $amount = ($row->getChildrenByTagName("Amount"))[0]->textContent();
          $amount{$account} = $amount;
        }
      }
    }
    else
    {
      # Just display error message
      print end_html;
      print header;
      print start_html(-title => "Gold Error",
                       -script => { -code => $java_script },
                       -onLoad => "updateStatus(\"message=$message\")"
        );
      print end_html;
      exit 0;
    }
  }

  # Merge member data elements with main data elements into the data element
  # Iterate over each row of data
  foreach my $row ($data->childNodes())
  {
    my $parent = ($row->getChildrenByTagName($primaryKeys[0]))[0]->textContent();
    foreach my $name (keys %{$members{$parent}})
    {
      my $newCol = new XML::LibXML::Element($name);
      foreach my $member (@{$members{$parent}{$name}})
      {
        my $newMember = new XML::LibXML::Element(substr($name, 0, -1));
        foreach my $field (keys %{$member})
        {
          next if $field eq $object; # Exclude parent foreign key
          my $newField = new XML::LibXML::Element($field);
          my $value = $member->{$field};
          $newField->appendText($value);
          $newMember->appendChild($newField);
        }
        $newCol->appendChild($newMember);
      }
      $row->appendChild($newCol);
    }
    if ($object eq "Account" && exists $objects{"Allocation"})
    {
      my $newCol = new XML::LibXML::Element("Amount");
      if (exists $amount{$parent})
      {
        $newCol->appendText($amount{$parent});
      }
      $row->appendChild($newCol);
    }
  }
}
else
{
  # Just display error message
  print end_html;
  print header;
  print start_html(-title => "Gold Error",
                   -script => { -code => $java_script },
                   -onLoad => "updateStatus(\"message=$message\")"
    );
  print end_html;
  exit 0;
}

# Convert xml data into a table
my $table = "";
my @fields = ();
my %values = ();
my @rows = $data->childNodes();
my $firstField = "Name";
if (@rows > 0)
{
  # Print Table Header
  $table .= <<END_OF_TABLE_TOP;
<table class="sortable" id="results" border="0" cellspacing="0">
  <thead>
    <tr>
END_OF_TABLE_TOP
  #$table .= "      <td colspan=\"1\" rowspan=\"2\"><div>Select</div></td>\n";
  my $count = 0; # Use to distinguish first column name
  foreach my $col (@columnInfo)
  {
    my $name = $col->{"Name"};
    push @fields, $name;
    $firstField = $name unless $count;
    my %fields = %{$col->{"Fields"}};
    if (scalar keys %fields)
    {
      $table .= "      <td colspan=\"" . (scalar(keys(%fields)) - 1) . "\" rowspan=\"1\"><div>$name</div></td>\n";
    }
    else
    {
      $table .= "      <td colspan=\"1\" rowspan=\"2\"><div>$name</div></td>\n";
    }
    $count++;
  }
  $table .= "    </tr>\n";
  $table .= "    <tr>\n";
  foreach my $col (@columnInfo)
  {
    my $name = $col->{"Name"};
    my %fields = %{$col->{"Fields"}};
    if (scalar keys %fields)
    {
      foreach my $field (sort by_field keys %fields)
      {
        next if $field eq $object; # Exclude parent foreign key
        $table .= "       <td><div>$field</div></td>\n";
      }
    }
  }
  $table .= "    </tr>\n  </thead>\n";

  # Print Table Body
  $table .= "  <tbody>\n";
  $count = 0; # Reset to count rows
  foreach my $row (@rows)
  {
    $table .= "    <tr id=\"row$count\">\n";
    my $conditions = ($row->getChildrenByTagName("_${action}"))[0]->textContent();
    #$table .= "      <td><a href=\"#\" onclick=\"selectAccount(\'1\');\">Select</a></td>\n";
    foreach my $col (@columnInfo)
    {
      my $name = $col->{"Name"};
      my %fields = %{$col->{"Fields"}};
      my $value = ($row->getChildrenByTagName($name))[0];
      my $text;
      if (defined $value)
      {
        $text = $value->textContent();
      }
      else
      {
        $text = "";
      }
      push @{$values{$name}}, $text;
      $text = "&nbsp;" if $text eq ""; # So border will be drawn
      if ($name eq "Id")
      {
        $table .= "      <td><a href=\"#\" onclick=\"selectAccount(\'$text\');\">$text</a></td>\n";
        next;
      }
      if (scalar keys %fields && defined $value)
      {
        my $fieldNum = scalar(keys(%fields)) - 1;
        $table .= "      <td colspan=\"$fieldNum\" valign=\"top\" style=\"padding: 0;\">";
        $table .= "        <table cellspacing=\"0\" border=\"0\" class=\"nested\" style=\"border: 0;\" cols=\"$fieldNum\" width=\"100%\">\n";
        foreach my $member ($value->childNodes())
        {
          $table .= "          <tr>\n";
          foreach my $field (sort by_field keys %fields)
          {
            next if $field eq $object;
            my $fieldValue = ($member->getChildrenByTagName($field))[0]->textContent();
            $table .= "            <td align=\"center\" style=\"border: 0; font-size: 100%;\">$fieldValue</td>";
          }
          $table .= "          </tr>\n";
        }
        $table .= "        </table>\n";
        $table .= "</td>\n";
      }
      else
      {
        $table .= "      <td colspan=\"" . (scalar(keys(%fields)) - 1) . "\">$text</td>\n";
      }
    }
    $table .= "    </tr>\n";
    $count++;
  }
  $table .= "  </tbody>\n</table>\n";
}

$java_script .= <<END_JAVA_SCRIPT;
  function filterResults() {
    var re = new RegExp(document.filterForm.filter.value, "gi");
    for( i=0; i<searchValues.length; i++) {
      var row = searchValues[i];
      if (row.search(re) != -1) {
        document.getElementById("row" + i).style.display = "";
      } else {
        document.getElementById("row" + i).style.display = "none";
      }
    }    
  }

END_JAVA_SCRIPT
foreach my $field (sort keys %values)
{
  $java_script .= "var ${field}Values = new Array(" . join(',', map "\"$_\"", @{$values{$field}}) . ");\n";
}
$java_script .= <<END_JAVA_SCRIPT;

function changeSearchField(field) {
    var sortedValues;
    var filterValues = [];
    
END_JAVA_SCRIPT
foreach my $field (sort @fields)
{
  $java_script .= <<END_JAVA_SCRIPT;
    if (field == "$field") {
      searchValues = ${field}Values;
      sortedValues = ${field}Values.slice().sort();
      for( i=0; i<sortedValues.length; i++) {
        if (sortedValues[i] !== sortedValues[i+1] ) {
          filterValues[filterValues.length] = sortedValues[i];
        }
      }    
    }
END_JAVA_SCRIPT
}
$java_script .= <<END_JAVA_SCRIPT;
    new AutoSuggest(document.getElementById('filter'), filterValues);
}

searchValues = ${firstField}Values;
END_JAVA_SCRIPT

my $style_sheet = <<END_STYLE_SHEET;
<!--
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

# Render the frame
my @statusInfo = ();
if ($message)
{
  $message = join '. ', split /\n/, $message; # Eliminate carriage returns
  push @statusInfo, "message=$message";
}
my $statusInfo = join '&', @statusInfo;

print header;
my $title = "Select Account";
print start_html(-title => $title,
                 -style => { -src => "/cgi-bin/gold/styles/gold.css",
                             -code => $style_sheet },
                 -script => [ { -src => "/cgi-bin/gold/scripts/autosuggest.js" },
                              { -src => "/cgi-bin/gold/scripts/sorttable.js" },
                              { -code => $java_script } ],
                 -onLoad => "updateStatus(\"$statusInfo\")"
  );
print_body();
print end_html;

sub print_body {
  # Print the header
  print div( { -id => "autosuggest" }, ul() ),
  div( { -class => "header" },
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
    h1($title) );

  # Print the filter
  print <<END_OF_FILTER_TOP;

<form name="filterForm" onSubmit="filterResults(); return false;" >
  <div align="center">
    <table style="border: 0;">
      <tr>
        <td>Search:</td>
        <td>By:</td>
      </tr>
      <tr>  
        <td><input name="filter" type="text" id="filter" /></td>
        <td>
          <select name="filter-by" onclick="changeSearchField(this[selectedIndex].text)">
END_OF_FILTER_TOP
  foreach my $field (@fields)
  {
    print "         <option>$field</option>\n";
  }
print <<END_OF_FILTER_BOTTOM;
          </select>
        </td>
      </tr>
    </table>
  </div>
</form>
<hr />
END_OF_FILTER_BOTTOM

  # Print the table
  my $lc_action = lc($action);
  $lc_action = "pre" . $lc_action if $lc_action eq "modify";
  print <<END_OF_FORM;
<form name="actionForm" method="post" action="${lc_action}.cgi">
  <div align="center">
    <input type="hidden" name="myobject" value="$object">
    <input type="hidden" name="myaction" value="$action">
    <input type="hidden" name="conditions" value="">
    $table
  </div>
</form>
END_OF_FORM
  #print "<!-- " . $data->toString() . " -->\n";
  print <<END_OF_JAVASCRIPT;
<script language="Javascript">
  new AutoSuggest(document.getElementById('filter'), ${firstField}Values);
</script>
END_OF_JAVASCRIPT
}
