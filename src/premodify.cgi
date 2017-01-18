#! /usr/bin/perl -wT
################################################################################
#
# Modify Form Frame for Gold Web GUI
#
# File   :  premodify.cgi
# History:  7 JULY 2005 [Scott Jackson] first implementation
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
my $conditions = $cgi->param("conditions");
my $objects_ref = $session->param("objects");
my %objects = %{$objects_ref};
my $actions_ref = $session->param("actions");
my %actions = %{$actions_ref};
my $attributes_ref = $session->param("attributes");
my %attributes = %{$attributes_ref};

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
            display: block;
        } 

        fieldset label {
            font-weight: bold;
            display: block;
        }

        fieldset select {
            width: 30%;
            float: left;
        }

        .activationTable {
            float: right;
            width: 66%;
        }

        .activationTable .headRow {
            border-bottom: 1px solid black;
            height: 2em;
        }

        .activationTable .headRow div {
            font-weight: bold;
            font-size: 105%;
        }

        .activationTable .activationRow {
            clear: both;
            border-bottom: 1px solid #A5C1E4;
            height: 2em;
            display: none;
        }

        .primaryKeyActivation, .active, .inactive {
            float: left;
            text-align: center;
            padding: .4em 0px;
        }

        .primaryKeyActivation {
            width: 45%;
        }

        .active, .inactive {
            width: 25%;
        }

        #selectInstructions {
            margin-top: 2em;
        }

-->
END_STYLE_SHEET

# Javascript to changeActivationTable
my $java_script = <<END_JAVA_SCRIPT;
function changeActivationTable(child) {
  //for each option, if it is selected make that activation row visible,
  //otherwise make it invisible
  //Also builds up the deleted and created input members
  //alert("child: "+ child);
  var selectbox = document.getElementById(child);
  var creations = document.getElementById(child + "Creations");
  var deletions = document.getElementById(child + "Deletions");
                                                                               
  // Reset the creations and deletions inputs
  creations.value = "";
  deletions.value = "";

  for(i = 0; i != selectbox.options.length; i++)
  {
    if(selectbox.options[i].value != "")
    {
      if(selectbox.options[i].selected == true)
      {
        document.getElementById(selectbox.options[i].value+child+"ActivationRow").style.display = "block";
        var found = false;
        for (j = 0; j != originalArray.length; j++)
        {
          if (child+selectbox.options[i].value == originalArray[j])
          {
            found = true;
          }
        }
        if (found == false)
        {
          // Add to created
          if (creations.value == "")
          {
            creations.value = selectbox.options[i].value;
          }
          else
          {
            creations.value = creations.value + "," + selectbox.options[i].value;
          }
        }
      }
      else
      {
        if(document.getElementById(selectbox.options[i].value+child+"ActivationRow").style.display == "block")
        {
          document.getElementById(selectbox.options[i].value+child+"ActivationRow").style.display = "none";
        }
        var found = false;
        for (j = 0; j != originalArray.length; j++)
        {
          if (child+selectbox.options[i].value == originalArray[j])
          {
            found = true;
          }
        }
        if (found == true)
        {
          // Add to deleted
          if (deletions.value == "")
          {
            deletions.value = selectbox.options[i].value;
          }
          else
          {
            deletions.value = deletions.value + "," + selectbox.options[i].value;
          }
        }
      }
    }
  }
}

function markChange(name){
  var changes = document.getElementById("changes");
  if (changes.value == "")
  {
    changes.value = name;
  }
  else
  {
    changes.value = changes.value + "," + name;
  }
}

function markModification(value, child, field){
  var modifications = document.getElementById(child + "Modifications");
  if (modifications.value == "")
  {
    modifications.value = value;
  }
  else
  {
    modifications.value = modifications.value + "," + value;
  }
}
END_JAVA_SCRIPT

# Print the modify form
print header;
print start_html(-title => "Modify $object",
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
    h1("Modify $object") );

  # Print symbol key
  print <<END_OF_SCREEN_TOP;
<p id="primaryKeyDesc">Primary key fields are marked with a key icon (<img alt="Primary Key" class="primaryKey" height="9" width="14" src="/cgi-bin/gold/images/primary_key.gif"/>)</p>
END_OF_SCREEN_TOP

  # Print the modify form
  print <<END_OF_SCREEN_TOP;
<form name="premodifyForm" method="post" action="modify.cgi">
  <input type="hidden" name="myobject" value="$object">
  <input type="hidden" name="myaction" value="$action">
  <input type="hidden" name="conditions" value="$conditions">
  <input type="hidden" name="changes" id="changes" value="">
  <input type="hidden" name="creations" id="creations" value="">
  <input type="hidden" name="deletions" id="deletions" value="">
  <input type="hidden" name="modifications" id="modifications" value="">
END_OF_SCREEN_TOP
                                                                                
  # Print the primary form elements

  # First figure out what the primary key of the foreign object is called
  my @names = ();
  my %primaryKeys = ();
  my %fixed = ();
  my %dataTypes = ();
  my %values = ();
  my %descriptions = ();
  foreach my $name (sort { $attributes{$object}{$a}{Sequence} <=> $attributes{$object}{$b}{Sequence} } keys %{$attributes{$object}})
  {
    my $hidden = $attributes{$object}{$name}{Hidden};
    my $primaryKey = $attributes{$object}{$name}{PrimaryKey};
    my $fixed = $attributes{$object}{$name}{Fixed};
    my $dataType = $attributes{$object}{$name}{DataType};
    my $values = $attributes{$object}{$name}{Values};
    my $defaultValue = $attributes{$object}{$name}{DefaultValue};
    my $description = $attributes{$object}{$name}{Description};

    next if $hidden eq "True";
    push @names, $name;
    $primaryKeys{$name} = $primaryKey;
    $fixed{$name} = $fixed;
    $dataTypes{$name} = $dataType;
    $values{$name} = $values;
    $descriptions{$name} = $description;
  }

  # SELECT @names from $object where @conditions
  my $request = new Gold::Request(object => $object, action => "Query", actor => $username);
  foreach my $name (@names)
  {
    $request->setSelection($name);
  }
  foreach my $condition (split /,/, $conditions)
  {
    my ($name, $value) = split /=/, $condition;
    $request->setCondition($name, $value);
  }
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

  # On success, add member data to the values hash
  my @rows = $data->childNodes();
  if (@rows > 0)
  {
    foreach my $col ($rows[0]->childNodes())
    {
      my $name = $col->nodeName();
      my $value = $col->textContent();
      my $primaryKey = $primaryKeys{$name};
      my $dataType = $dataTypes{$name};
      my $values = $values{$name};
      my $description = $descriptions{$name};

      # Handle All Data Types
      print <<END_OF_SCREEN_SECTION;
    <div class="row">
      <label class="rowLabel" for="$name">
END_OF_SCREEN_SECTION
      if ($primaryKey eq "True")
      {
        print "<img alt=\"Primary Key\" class=\"primaryKey\" height=\"9\" width=\"14\" src=\"/cgi-bin/gold/images/primary_key.gif\"/>";
      }
      print "$description:</label>\n";
  
      if ($fixed{$name} eq "True")
      {
        print <<END_OF_SCREEN_SECTION;
      <input disabled="y" maxlength="" size="30" value="$value" id="$name" name="${name}Assignment" type="text"/>
END_OF_SCREEN_SECTION
      }
      elsif ($dataType eq "Boolean")
      {
        print "      <input onchange=\"markChange(\'${name}Assignment\');\" type=\"radio\" name=\"${name}Assignment\" id=\"$name\" value=\"True\"";
        print " CHECKED" if $value eq "True";
        print ">True\n";
        print "      <input onchange=\"markChange(\'${name}Assignment\');\" type=\"radio\" name=\"${name}Assignment\" id=\"$name\" value=\"False\"";
        print " CHECKED" if $value eq "False";
        print ">False\n";
      }
      elsif ($values)
      {
        print <<END_OF_SCREEN_SECTION;
      <select onchange=\"markChange(\'${name}Assignment\');\" id="$name" name="${name}Assignment">
END_OF_SCREEN_SECTION
        print "      <Option value=\"$value\">$value</Option>\n";
  
        # Check to see if this is a foreign key
        if ($values =~ /^@/)
        {
          $values = substr($values, 1);
  
          # First figure out what the primary key of the foreign object is called
          my $key;
          my $hasSpecial = 0;
          foreach my $attribute (keys %{$attributes{$values}})
          {
            if ($attribute eq "Special") { $hasSpecial = 1; }
            if ($attributes{$values}{$attribute}{"PrimaryKey"} eq "True")
            {
              $key ||= $attribute;
            }
          }
          $key ||= "Name";
  
          # SELECT $key from $values
          my $request = new Gold::Request(object => $values, action => "Query", actor => $username);
          $request->setSelection($key);
          $request->setCondition("Special", "False") if $hasSpecial;
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
  
          # On success, add member data to the select
          if ($status ne "Failure")
          {
            foreach my $row ($data->childNodes())
            {
              my $val = ($row->childNodes())[0]->textContent();
              print "      <Option value=\"$val\">$val</Option>\n" unless $val eq $value;
            }
          }
        }
  
        # See if it is a member of a list
        elsif ($values =~ /^\((.*)\)$/)
        {
          my @valueList = split /,/, $1;
          foreach my $val (@valueList)
          {
            print "      <Option value=\"$val\">$val</Option>\n" unless $val eq $value;
          }
        }
  
        print "    </select>\n";
      }
      else
      {
        print <<END_OF_SCREEN_SECTION;
      <input onchange=\"markChange(\'${name}Assignment\');\" maxlength="" size="30" value="$value" id="$name" name="${name}Assignment" type="text"/>
END_OF_SCREEN_SECTION
      }
      print "  </div>\n";
    }
  }

  # Build up a list of associations from %objects
  my @associations = ();
  my @originals = ();
  foreach my $name (sort keys %objects)
  {
    if ($objects{$name}{"Association"} eq "True" && $objects{$name}{"Parent"} eq $object && $actions{$name}{"Query"}{"Display"} eq "True")
    {
      push @associations, $name;
    }
  }

  # Iterate over all associations
  if (@associations)
  {
    print <<END_OF_SCREEN;
    <hr/>
<p id="selectInstructions">You can select multiple items from select fields by holding down 'Ctrl' on PCs and 'Cmd' on Macs.</p>
END_OF_SCREEN

    foreach my $association (sort by_association @associations)
    {
      my $child = $objects{$association}{"Child"};

      print <<END_OF_SCREEN;
  <input type="hidden" name="${child}Creations" id="${child}Creations" value="">
  <input type="hidden" name="${child}Deletions" id="${child}Deletions" value="">
  <input type="hidden" name="${child}Modifications" id="${child}Modifications" value="">
END_OF_SCREEN
                                                                                
      print <<END_OF_SCREEN;
<div class="row">
<fieldset id="${child}Fieldset">
<legend>${child}s</legend>
<div class="activationTable" id="${child}Activation">
<div class="headRow">
END_OF_SCREEN
    
      # Build a list of association fields
      my @fields = ();
      my %dataType = ();
      my %default = ();
      foreach my $name (sort { $attributes{$association}{$a}{Sequence} <=> $attributes{$association}{$b}{Sequence} } keys %{$attributes{$association}})
      {
        my $hidden = $attributes{$association}{$name}{Hidden};
        my $primaryKey = $attributes{$association}{$name}{PrimaryKey};
        my $required = $attributes{$association}{$name}{Required};
        my $dataType = $attributes{$association}{$name}{DataType};
        my $values = $attributes{$association}{$name}{Values};
        my $defaultValue = $attributes{$association}{$name}{DefaultValue};
        my $description = $attributes{$association}{$name}{Description};

        next if $hidden eq "True";
        next if $name eq $object; # We don't want the parent key
        push @fields, $name;

        $dataType{$name} = $dataType;
        $default{$name} = $defaultValue;
        if ($primaryKey eq "True")
        {
          print "<div class=\"primaryKeyActivation\">$name</div>\n";
        }
        else
        {
          print "<div class=\"active\">$name</div>\n";
        }
      }
      print "</div>\n";

      # Obtain child primary key and determine if special
      my $key = "";
      my $hasSpecial = 0;
      foreach my $name (sort { $attributes{$child}{$a}{Sequence} <=> $attributes{$child}{$b}{Sequence} } keys %{$attributes{$child}})
      {
        my $hidden = $attributes{$child}{$name}{Hidden};
        my $primaryKey = $attributes{$child}{$name}{PrimaryKey};

        if ($name eq "Special") { $hasSpecial = 1; }
        next if $hidden eq "True";
        if ($primaryKey eq "True")
        {
          $key ||= $name;
        }
      }

      # Build and issue the association Request
      # SELECT @fields FROM $association where $object=$value
      my $request = new Gold::Request(object => $association, action => "Query", actor => $username);
      foreach my $name (@fields)
      {
        if ($name eq $key) { $request->setSelection($name, "Sort"); }
        else { $request->setSelection($name); }
      }
      my $keyValue = "";
      foreach my $condition (split /,/, $conditions)
      {
        my ($name, $value) = split /=/, $condition;
        $keyValue ||= $value if $primaryKeys{$name} eq "True";
      }
      $request->setCondition($object, $keyValue);
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

      my %children = ();
      foreach my $row ($data->childNodes())
      {
        my $childValue = "";
        foreach my $col ($row->childNodes())
        {
          my $name = $col->nodeName();
          my $value = $col->textContent();
          if ($name eq $key)
          {
            $childValue ||= $value;
            push @originals, "${child}${value}";
          }
          else
          {
            $children{$childValue}{$name} = $value;
          }
        }
      }

      # Build and issue the child Request
      # SELECT @names FROM $child
      $request = new Gold::Request(object => $child, action => "Query", actor => $username);
      $request->setSelection($key, "Sort");
      $request->setCondition("Special", "False") if $hasSpecial;
      $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
      $messageChunk->setRequest($request);
      $replyChunk = $messageChunk->getChunk();
      $response = $replyChunk->getResponse();
      $status = $response->getStatus();
      $message = $response->getMessage();
      $data = $response->getDataElement();
      $count = $response->getCount();
      $doc = XML::LibXML::Document->new();
      $doc->setDocumentElement($data);

      # On success, add member data to the select
      if ($status ne "Failure")
      {
        my @members = ();
        foreach my $row ($data->childNodes())
        {
          my $name = ($row->childNodes())[0]->nodeName();
          my $value = ($row->childNodes())[0]->textContent();
          foreach my $field (@fields)
          {
            # We assume the primary key will always be listed first
            if ($field eq $key)
            {
              push @members, $value;
              my $style = "";
              if (exists $children{$value})
              {
                $style = " style=\"display:block;\"";
              }
              print <<END_OF_SCREEN;
<div ${style}id="${value}${child}ActivationRow" class="activationRow">
<div class="primaryKeyActivation">$value</div>
END_OF_SCREEN
            }
            else
            {
              print "<div class=\"active\">\n";
              my $preValue = "";
              if (exists $children{$value} && exists $children{$value}{$field})
              {
                $preValue = $children{$value}{$field};
              }
              else
              {
                $preValue = $default{$field};
              }
              if ($dataType{$field} eq "Boolean")
              {
                my $checked = "";
                if ($preValue eq "True")
                {
                  $checked = " CHECKED";
                }
                print "<input onchange=\"markModification(\'$value\',\'$child\',\'$field\');\" id=\"${value}${child}${field}\" name=\"${value}${child}${field}\" value=\"True\" type=\"checkbox\"$checked/>\n";
              }
              else
              {
                print "<input onchange=\"markModification(\'$value\',\'$child\',\'$field\');\" type=\"text\" name=\"${value}${child}${field}\" id=\"${value}${child}${field}\" value=\"$preValue\" size=\"10\" maxlength=\"80\"/>\n";
              }
              print "</div>\n";
            } 
          }
          print "</div>\n";
        }
        print <<END_OF_SCREEN;
</div>
<div id="${child}MultiSelect" class="multiSelect">
<label for="$child">${child}s</label>
<select multiple="yes" size="10" id="$child" name="$child" onchange="changeActivationTable(\'$child\');">
END_OF_SCREEN

        foreach my $member (@members)
        {
          my $selected = "";
          if (grep($_ eq $member, keys %children))
          {
            $selected = " SELECTED";
          }
          print "<option value=\"$member\"$selected>$member</option>\n";
        }
        print "</select>\n</div>\n";
      }
      foreach my $field (@fields)
      {
        print "<input id=\"${object}${child}${field}\" name=\"${object}${child}${field}\" type=\"hidden\">\n";
      }
      print "</fieldset>\n</div>\n";
    }
  }

  print <<END_OF_SCREEN_BOTTOM;
  <hr />
  <div id="submitRow">
    <input type="submit" value="Modify $object">
  </div>
</form>
END_OF_SCREEN_BOTTOM

  # Build original array of association values in javascript
  my $originalArray = join ',', map "\"$_\"", @originals;
   print <<END_OF_JAVASCRIPT;
<script language="Javascript">
var originalArray = new Array($originalArray);
</script>
END_OF_JAVASCRIPT
}


