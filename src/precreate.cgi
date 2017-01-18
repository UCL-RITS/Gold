#! /usr/bin/perl -wT
################################################################################
#
# Create Form Frame for Gold Web GUI
#
# File   :  precreate.cgi
# History:  9 JUN 2005 [Scott Jackson] first implementation
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
            display: none;
        } 

        fieldset label {
            font-weight: bold;
            /* display: block; */
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

# Javascript to changeActivationTable and getValue
my $java_script = <<END_JAVA_SCRIPT;
function changeActivationTable(type) {
  //for each option, if it is selected make that activation row visible,
  //otherwise make it invisible
  //alert("type: "+ type);
  var selectbox = document.getElementById(type);
                                                                               
  for(i = 0; i != selectbox.options.length; i++) {
    if(selectbox.options[i].value != ""){
      if(selectbox.options[i].selected == true)
        document.getElementById(selectbox.options[i].value+type+"ActivationRow").style.display = "block";
      else if(document.getElementById(selectbox.options[i].value+type+"ActivationRow").style.display == "block")
        document.getElementById(selectbox.options[i].value+type+"ActivationRow").style.display = "none";
    }
  }

  //Check the checkboxes too if they are there
  var specials = new Array("ANY", "MEMBERS", "NONE");
  for(i = 0; i != specials.length; i++) {
  if(document.getElementById(new String(type + specials[i]))){
    //alert(specials[i]+type+"ActivationRow");
    if(document.getElementById(new String(type + specials[i])).checked)
      document.getElementById(specials[i]+type+"ActivationRow").style.display = "block";
    else if(document.getElementById(specials[i]+type+"ActivationRow").style.display == "block")
      document.getElementById(specials[i]+type+"ActivationRow").style.display = "none";
    }
  }
}

function getValue(who, type, field){
  if (document.getElementById(who+type+field))
  {
    if(document.getElementById(who+type+field).type == 'checkbox')
    {
      if(document.getElementById(who+type+field).checked)
        return "True";
      else
        return "False";
    }
    else
    {
      return document.getElementById(who+type+field).value;
    }
  }
  else
  {
    return who;
  }
}

function setDefaults(object)
{
  if (object=='Account')
  {
    changeActivationTable('User'); 
    setMembers('User', 'Account');
    changeActivationTable('Machine'); 
    setMembers('Machine', 'Account');
  }
}

function submitForm(object)
{
  if(object=="Account")
  {
    if(document.getElementById('ProjectANY').checked == false && document.getElementById('Project').value == ""){
      alert("Please select at least one project.");
      return false;
    }else if(document.getElementById('UserANY').checked == false && document.getElementById('UserMEMBERS').checked == false && document.getElementById('UserNONE').checked == false && document.getElementById('User').value == ""){
       alert("Please select at least one user.");
       return false;
    }else if(document.getElementById('MachineANY').checked == false && document.getElementById('MachineMEMBERS').checked == false && document.getElementById('Machine').value == ""){
       alert("Please select at least one machine.");
       return false;
    }
    if (document.getElementById('Name').value == ""){
      var accountName = new Array();
      if (document.getElementById('Project').value != "") {
        accountName.push(document.getElementById('Project').value);
      }
      if (document.getElementById('Machine').value != "") {
        accountName.push('on ' + document.getElementById('Machine').value);
      }
      if (document.getElementById('User').value != "") {
        accountName.push('for ' + document.getElementById('User').value);
      }
      if (accountName.length > 0) {
        document.getElementById('Name').value = accountName.join(' ');
      }
    }
  }
  document.inputForm.submit();
}

function toggleSelect(selectName)
{
  if(document.getElementById(new String(selectName + 'SPECIFIC')).checked )
    document.getElementById(selectName).disabled = false;
  else
    document.getElementById(selectName).disabled = true;
}

END_JAVA_SCRIPT

# Print the create form
print header;
print start_html(-title => "Create New $object",
                 -script => { -code => $java_script },
                 -style => { -code => $style_sheet },
                 -onLoad => "setDefaults(\'$object\');"
);
print_body();
print end_html;

sub print_body
{
  # Begin dynamic setMembers Javascript function
  my $set_members = <<END_OF_JAVASCRIPT;
function setMembers(type, object){
END_OF_JAVASCRIPT

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
    h1("Create New $object") );

  # Print symbol key
  print <<END_OF_SCREEN_TOP;
<p id="requiredDesc">Fields marked with a red asterisk (<span class="required">*</span>) are required.</p>
<p id="primaryKeyDesc">Primary key fields are marked with a key icon (<img alt="Primary Key" class="primaryKey" height="9" width="14" src="/cgi-bin/gold/images/primary_key.gif"/>)</p>
END_OF_SCREEN_TOP

  # Print the create form
  print <<END_OF_SCREEN_TOP;
<form name="inputForm" method="post" action="create.cgi">
  <input type="hidden" name="myobject" value="$object">
  <input type="hidden" name="myaction" value="$action">
END_OF_SCREEN_TOP
                                                                                
  # Print the primary form elements
  foreach my $name (sort { $attributes{$object}{$a}{Sequence} <=> $attributes{$object}{$b}{Sequence} } keys %{$attributes{$object}})
  {
    my $hidden = $attributes{$object}{$name}{Hidden};
    my $primaryKey = $attributes{$object}{$name}{PrimaryKey};
    my $required = $attributes{$object}{$name}{Required};
    my $dataType = $attributes{$object}{$name}{DataType};
    my $values = $attributes{$object}{$name}{Values};
    my $defaultValue = $attributes{$object}{$name}{DefaultValue};
    my $description = $attributes{$object}{$name}{Description};

    next if $hidden eq "True";
    next if $dataType eq "AutoGen";

    # Handle All Data Types
    print <<END_OF_SCREEN_SECTION;
  <div class="row">
    <label class="rowLabel" for="$name">
END_OF_SCREEN_SECTION
    if ($primaryKey eq "True")
    {
      print "<img alt=\"Primary Key\" class=\"primaryKey\" height=\"9\" width=\"14\" src=\"/cgi-bin/gold/images/primary_key.gif\"/>";
    }
    if ($required eq "True")
    {
      print "<span class=\"required\">*</span>";
    }
    #print "$description:</label>\n";
    print "$name:</label>\n";

    if ($dataType eq "Boolean")
    {
      print "      <input type=\"radio\" name=\"$name\" value=\"True\"";
      print " CHECKED" if $defaultValue eq "True";
      print ">True\n";
      print "      <input type=\"radio\" name=\"$name\" value=\"False\"";
      print " CHECKED" if $defaultValue eq "False";
      print ">False\n";
    }
    elsif ($values)
    {
      print <<END_OF_SCREEN_SECTION;
    <select id="$name" name="${name}Assignment">
END_OF_SCREEN_SECTION
      print "      <Option value=\"$defaultValue\">$defaultValue</Option>\n" if defined $defaultValue;

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
            my $value = ($row->childNodes())[0]->textContent();
            print "      <Option value=\"$value\">$value</Option>\n" unless $value eq $defaultValue;
          }
        }
      }

      # See if it is a member of a list
      elsif ($values =~ /^\((.*)\)$/)
      {
        my @valueList = split /,/, $1;
        foreach my $value (@valueList)
        {
          print "      <Option value=\"$value\">$value</Option>\n" unless $value eq $defaultValue;
        }
      }

      print "    </select>\n";
    }
    else
    {
      print <<END_OF_SCREEN_SECTION;
    <input maxlength="" size="30" value="$defaultValue" id="$name" name="${name}Assignment" type="text"/>
END_OF_SCREEN_SECTION
    }
    print "  </div>\n";
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

      # Open a setMembers section for each child type
      my $member_object = <<END_OF_JAVASCRIPT;
  if (type == "$child")
  {
END_OF_JAVASCRIPT

      # Build the opening setMembers internal sections
      my $element_bind = <<END_OF_JAVASCRIPT;
    // 1. bind the hidden inputs to the javascript var names
    // hidden inputs named "{object}{child}{field}"
    // alert(type +", " + object);
    var nameSelect = document.getElementById(type);
END_OF_JAVASCRIPT

  my $reset_values = <<END_OF_JAVASCRIPT;
    // 2. reset the values of the hidden inputs
END_OF_JAVASCRIPT

  my $select_build = <<END_OF_JAVASCRIPT;
    // 3. loop thru those selected on the list and add to input list
    for(var i = 0; i != nameSelect.options.length; i++){
      if(nameSelect.options[i].selected){
END_OF_JAVASCRIPT

  my $check_checkboxes = <<END_OF_JAVASCRIPT;
    // 4. Check the checkboxes too if they are there
    var specials = new Array("ANY", "MEMBERS", "NONE");
    for(i = 0; i != specials.length; i++) {
      var specialCheckbox = document.getElementById(new String(type + specials[i]));
      //alert(specials[i]+type+"ActivationRow");
      if(specialCheckbox.checked){
END_OF_JAVASCRIPT

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

        # Build the core setMembers internal sections
        $element_bind .= <<END_OF_JAVASCRIPT;
    var hiddenElement${name} = document.getElementById(object+nameSelect.name+"$name");
END_OF_JAVASCRIPT

        $reset_values .= <<END_OF_JAVASCRIPT;
    hiddenElement${name}.value = "";
END_OF_JAVASCRIPT

        $select_build .= <<END_OF_JAVASCRIPT;
        if (hiddenElement${name}.value == ""){
          hiddenElement${name}.value = hiddenElement${name}.value + getValue(nameSelect.options[i].value, type, "$name");
        }
        else {
          hiddenElement${name}.value = hiddenElement${name}.value + "," + getValue(nameSelect.options[i].value, type, "$name");
        }
END_OF_JAVASCRIPT
    
        $check_checkboxes .= <<END_OF_JAVASCRIPT;
        if (hiddenElement${name}.value == ""){
          hiddenElement${name}.value = hiddenElement${name}.value + getValue(specialCheckbox.value, type, "$name");
        }
        else {
          hiddenElement${name}.value = hiddenElement${name}.value + "," + getValue(specialCheckbox.value, type, "$name");
        }
END_OF_JAVASCRIPT

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

      # Build list of children to select from
      my $key = "";
      my $hasSpecial = 0;
      foreach my $name (sort { $attributes{$child}{$a}{Sequence} <=> $attributes{$child}{$b}{Sequence} } keys %{$attributes{$child}})
      {
        my $hidden = $attributes{$child}{$name}{Hidden};
        my $primaryKey = $attributes{$child}{$name}{PrimaryKey};
        my $required = $attributes{$child}{$name}{Required};
        my $dataType = $attributes{$child}{$name}{DataType};
        my $values = $attributes{$child}{$name}{Values};
        my $defaultValue = $attributes{$child}{$name}{DefaultValue};
        my $description = $attributes{$child}{$name}{Description};

        if ($name eq "Special") { $hasSpecial = 1; }
        next if $hidden eq "True";
        if ($primaryKey eq "True")
        {
          $key ||= $name;
        }
      }

      # Build and issue the associated Request
      # SELECT @names FROM $child
      my $request = new Gold::Request(object => $child, action => "Query", actor => $username);
      $request->setSelection($key);
      $request->setSelection("Special") if $hasSpecial;
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
        my @members = ();
        foreach my $row ($data->childNodes())
        {
          my $name = ($row->childNodes())[0]->nodeName();
          my $value = ($row->childNodes())[0]->textContent();
          my $special = "False";
          $special = ($row->childNodes())[1]->textContent() if $hasSpecial;
          foreach my $field (@fields)
          {
            # We assume the primary key will always be listed first
            if ($field eq $key)
            {
              push @members, $value unless $special eq "True";
              print <<END_OF_SCREEN;
<div id="${value}${child}ActivationRow" class="activationRow">
<div class="primaryKeyActivation">$value</div>
END_OF_SCREEN
            }
            else
            {
              print "<div class=\"active\">\n";
              if ($dataType{$field} eq "Boolean")
              {
                my $checked = "";
                if ($default{$field} eq "True")
                {
                  $checked = " CHECKED";
                }
                print "<input onchange=\"setMembers(\'$child\', \'$object\');\" id=\"${value}${child}${field}\" name=\"${value}${child}${field}\" value=\"True\" type=\"checkbox\"$checked/>\n";
              }
              else
              {
                print "<input type=\"text\" onchange=\"setMembers(\'$child\', \'$object\');\" name=\"${value}${child}${field}\" id=\"${value}${child}${field}\" value=\"$default{$field}\" size=\"10\" maxlength=\"80\"/>\n";
              }
              print "</div>\n";
            } 
          }
          print "</div>\n";
        }
        print "</div>\n";
        
        if ($object eq "Account")
        {
          if ($child eq "Project")
          {
            print <<END_OF_SCREEN;
<input onclick="changeActivationTable('Project'); setMembers('Project', 'Account');" value="ANY" id="ProjectANY" name="ProjectRadio" type="checkbox"/>
<label for="ProjectANY"> Any </label>
<br/>
<input onclick="toggleSelect('Project')" value="NONE" id="ProjectNONE" name="ProjectRadio" type="checkbox"/>
<label for="ProjectNONE"> None </label>
<br/>
<input onclick="toggleSelect('Project')" value="ProjectSPECIFIC" id="ProjectSPECIFIC" name="ProjectRadio" type="checkbox" checked="true"/>
<label for="ProjectSPECIFIC"> Specific Projects</label>
<br/>
<br/>            
END_OF_SCREEN
          }
          elsif ($child eq "User")
          {
            print <<END_OF_SCREEN;
<input onclick="changeActivationTable('User'); setMembers('User', 'Account');" value="ANY" id="UserANY" name="UserRadio" type="checkbox"/>
<label for="UserANY"> Any </label>
<br/>
<input onclick="changeActivationTable('User'); setMembers('User', 'Account');" value="MEMBERS" id="UserMEMBERS" name="UserRadio" type="checkbox" checked="true"/>
<label for="UserMEMBERS"> Member </label>
<br/>
<input onclick="changeActivationTable('User'); setMembers('User', 'Account');" value="NONE" id="UserNONE" name="UserRadio" type="checkbox"/>
<label for="UserNONE"> None </label>
<br/>
<input onclick="toggleSelect('User')" value="UserSPECIFIC" id="UserSPECIFIC" name="UserRadio" type="checkbox"/>
<label for="UserSPECIFIC"> Specific Users</label>
<br/>
<br/>
END_OF_SCREEN
          }
          elsif ($child eq "Machine")
          {
            print <<END_OF_SCREEN;
<input onclick="changeActivationTable('Machine'); setMembers('Machine', 'Account');" value="ANY" id="MachineANY" name="MachineRadio" type="checkbox" checked="true"/>
<label for="MachineANY"> Any </label>
<br/>
<input onclick="changeActivationTable('Machine'); setMembers('Machine', 'Account');" value="MEMBERS" id="MachineMEMBERS" name="MachineRadio" type="checkbox"/>
<label for="MachineMEMBERS"> Member </label>
<br/>
<input onclick="changeActivationTable('Machine'); setMembers('Machine', 'Account');" value="NONE" id="MachineNONE" name="MachineRadio" type="checkbox"/>
<label for="MachineNONE"> None </label>
<br/>
<input onclick="toggleSelect('Machine')" value="MachineSPECIFIC" id="MachineSPECIFIC" name="MachineRadio" type="checkbox"/>
<label for="MachineSPECIFIC"> Specific Machines</label>
<br/>
<br/>
END_OF_SCREEN
          }
        }

        my $disabled = "";
        if ($object eq "Account")
        {
          if ($child eq "User" || $child eq "Machine")
          {
            $disabled = " disabled=\"true\"";
          }
        }
        print <<END_OF_SCREEN;
<div id="${child}MultiSelect" class="multiSelect">
<label for="$child">${child}s</label>
<select multiple="yes" size="10" id="$child" name="$child" onchange="changeActivationTable(\'$child\'); setMembers(\'$child\', \'$object\');"$disabled>
END_OF_SCREEN
        foreach my $member (@members)
        {
          print "<option value=\"$member\">$member</option>\n";
        }
        print "</select>\n</div>\n";
      }
      foreach my $field (@fields)
      {
        print "<input id=\"${object}${child}${field}\" name=\"${object}${child}${field}\" type=\"hidden\">\n";
      }
      print "</fieldset>\n</div>\n";

      # Build the closing setMembers internal sections
      $select_build .= <<END_OF_JAVASCRIPT;
      }
    }
END_OF_JAVASCRIPT
      $check_checkboxes .= <<END_OF_JAVASCRIPT;
      }
    }
END_OF_JAVASCRIPT

      # Close a setMembers section for each child type
      $member_object .= <<END_OF_JAVASCRIPT;

$element_bind

$reset_values

$select_build

$check_checkboxes
  }
END_OF_JAVASCRIPT

      # Add member_object to $set_members
      $set_members .= <<END_OF_JAVASCRIPT;

$member_object
END_OF_JAVASCRIPT
    }
  }

  print <<END_OF_SCREEN_BOTTOM;
  <hr />
  <div id="submitRow">
    <input onclick="submitForm(\'$object\')" value="Create New $object" id="formSubmit" name="create" type="button">
  </div>
</form>
END_OF_SCREEN_BOTTOM

  # End dynamic setMembers Javascript function
  $set_members .= <<END_OF_JAVASCRIPT;
}
END_OF_JAVASCRIPT

   print <<END_OF_JAVASCRIPT;
<script language="Javascript">
$set_members
</script>
END_OF_JAVASCRIPT
}


