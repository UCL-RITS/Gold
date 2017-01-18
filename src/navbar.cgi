#! /usr/bin/perl -wT
################################################################################
#
# Navigation Menu for Gold Web GUI
#
# File   :  navbar.cgi
# History:  2 MAY 2005 [Scott Jackson] first implementation
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

my %priv = ();
my %objects = ();
my %actions = ();
my %attributes = ();

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, { Directory => "/tmp" });
unless ($session->param("username") && $session->param("password"))
{
  print redirect(-location => "login.cgi");
  exit(0);
}

# Session variables include:
# ==========================
# $username
# $password
# $myobject
# $myaction
# $priv{$object}{$action} = $instance
# $objects{$name}{$propertyName} = $propertyValue 
# $actions{$object}{$name}{$propertyName} = $propertyValue 
# $attributes{$object}{$name}{$propertyName} = $propertyValue 
# $data{$primaryKey}{$fieldName} = $fieldValue 
# $filtered_data{$primaryKey}{$fieldName} = $fieldValue 
# $selected{$primaryKey}

my $username = $session->param("username");
my $password = $session->param("password");
my $isadmin = $session->param("isadmin");
my $priv_ref = $session->param("priv");
my $objects_ref = $session->param("objects");
my $actions_ref = $session->param("actions");
my $attributes_ref = $session->param("attributes");

# Determine the objects and actions that should be displayed for this user
# If the priv session variable is undefined, populate it via a query
if (defined $priv_ref)
{
  %priv = %{$priv_ref};
}
else
{
  my ($request, $messageChunk, $replyChunk, $response, $status);
  my $role_ref = {};

  # RoleAction,RoleUser Query RoleAction.Role==RoleUser.Role (RoleUser.Name==$username || RoleUser.Name==ANY) Show:="RoleAction.Role,RoleAction.Object,RoleAction.Name,RoleAction.Instance" Unique:=True
  $request = new Gold::Request(action => "Query", actor => $username);
  $request->setObject("RoleAction");
  $request->setObject("RoleUser");
  $request->setSelection(new Gold::Selection(object => "RoleAction", name => "Role"));
  $request->setSelection(new Gold::Selection(object => "RoleAction", name => "Object"));
  $request->setSelection(new Gold::Selection(object => "RoleAction", name => "Name", alias => "Action"));
  $request->setSelection(new Gold::Selection(object => "RoleAction", name => "Instance"));
  $request->setCondition(new Gold::Condition(object => "RoleAction", name => "Role", subject => "RoleUser", value => "Role"));
  $request->setCondition(new Gold::Condition(object => "RoleUser", name => "Name", value => $username, group => "+1", conj => "And"));
  $request->setCondition(new Gold::Condition(object => "RoleUser", name => "Name", value => "ANY", group => "-1", conj => "Or"));
  $request->setOption(new Gold::Option(name => "Unique", value => "True"));
  $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
  $messageChunk->setRequest($request);
  $replyChunk = $messageChunk->getChunk();
  $response = $replyChunk->getResponse();
  $status = $response->getStatus();

  if ($status eq "Success")
  {
    my @data = $response->getData();
    foreach my $datum (@data)
    {
      my $role = $datum->getValue("Role");
      my $object = $datum->getValue("Object");
      my $action = $datum->getValue("Action");
      my $instance = $datum->getValue("Instance");
      $role_ref->{$object}{$action}{$instance} = 1;

      # Mark whether this user is a system administrator
      if ($role eq "SystemAdmin")
      {
        $isadmin = "True";
        $session->param("isadmin", "True");
      }
    }
  }

  # Object,Action Query Object.Name==Action.Object Object.Association==False Action.Display==True Show:="Action.Object,Action.Name[as Action]"
  $request = new Gold::Request(action => "Query", actor => $username);
  $request->setObject("Object");
  $request->setObject("Action");
  $request->setSelection(new Gold::Selection(object => "Action", name => "Object"));
  $request->setSelection(new Gold::Selection(object => "Action", name => "Name", alias => "Action"));
  $request->setCondition(new Gold::Condition(object => "Object", name => "Name", subject => "Action", value => "Object"));
  $request->setCondition(new Gold::Condition(object => "Object", name => "Association", value => "False"));
  $request->setCondition(new Gold::Condition(object => "Action", name => "Display", value => "True"));
  $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
  $messageChunk->setRequest($request);
  $replyChunk = $messageChunk->getChunk();
  $response = $replyChunk->getResponse();
  $status = $response->getStatus();

  if ($status eq "Success")
  {
    my @data = $response->getData();
    foreach my $datum (@data)
    {
      my $object = $datum->getValue("Object");
      my $action = $datum->getValue("Action");
      foreach my $role_object (keys %{$role_ref})
      {
        next unless ($role_object eq $object || $role_object eq "ANY");
        foreach my $role_action (keys %{$role_ref->{$role_object}})
        {
          next unless ($role_action eq $action || $role_action eq "ANY");
          foreach my $role_instance (keys %{$role_ref->{$role_object}{$role_action}})
          {
            if (! exists($priv_ref->{$object}{$action}) || instance_generality($role_instance) > instance_generality($priv_ref->{$object}{$action}))
            {
              $priv_ref->{$object}{$action} = $role_instance;
            }
          }
        }
      }
    }
    $session->param("priv", $priv_ref);
    %priv = %{$priv_ref};
  }
}

# Set Objects Session Variable
if (defined $objects_ref)
{
  %objects = %{$objects_ref};
}
else
{
  my ($request, $messageChunk, $replyChunk, $response, $status);

  # Object Query
  $request = new Gold::Request(action => "Query", actor => $username);
  $request->setObject("Object");
  $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
  $messageChunk->setRequest($request);
  $replyChunk = $messageChunk->getChunk();
  $response = $replyChunk->getResponse();
  $status = $response->getStatus();
  if ($status eq "Success")
  {
    my @data = $response->getData();
    foreach my $datum (@data)
    {
      my $name = $datum->getValue("Name");
      next if ($name eq "ANY" || $name eq "NONE");
      my $element = $datum->getElement();
      foreach my $property ($element->childNodes())
      {
        my $propertyName = $property->nodeName();
        my $propertyValue = $property->textContent();
        $objects_ref->{$name}{$propertyName} = $propertyValue;
      }
    }
    $session->param("objects", $objects_ref);
    %objects = %{$objects_ref};
  }
}

# Set Attributes Session Variable
if (defined $attributes_ref)
{
  %attributes = %{$attributes_ref};
}
else
{
  my ($request, $messageChunk, $replyChunk, $response, $status);

  # Attribute Query
  $request = new Gold::Request(action => "Query", actor => $username);
  $request->setObject("Attribute");
  $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
  $messageChunk->setRequest($request);
  $replyChunk = $messageChunk->getChunk();
  $response = $replyChunk->getResponse();
  $status = $response->getStatus();
  if ($status eq "Success")
  {
    my @data = $response->getData();
    foreach my $datum (@data)
    {
      my $object = $datum->getValue("Object");
      my $name = $datum->getValue("Name");
      my $element = $datum->getElement();
      foreach my $property ($element->childNodes())
      {
        my $propertyName = $property->nodeName();
        my $propertyValue = $property->textContent();
        $attributes_ref->{$object}{$name}{$propertyName} = $propertyValue;
      }
    }
    $session->param("attributes", $attributes_ref);
    %attributes = %{$attributes_ref};
  }
}

# Set Actions Session Variable
if (defined $actions_ref)
{
  %actions = %{$actions_ref};
}
else
{
  my ($request, $messageChunk, $replyChunk, $response, $status);

  # Action Query
  $request = new Gold::Request(action => "Query", actor => $username);
  $request->setObject("Action");
  $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
  $messageChunk->setRequest($request);
  $replyChunk = $messageChunk->getChunk();
  $response = $replyChunk->getResponse();
  $status = $response->getStatus();
  if ($status eq "Success")
  {
    my @data = $response->getData();
    foreach my $datum (@data)
    {
      my $object = $datum->getValue("Object");
      my $name = $datum->getValue("Name");
      my $element = $datum->getElement();
      foreach my $property ($element->childNodes())
      {
        my $propertyName = $property->nodeName();
        my $propertyValue = $property->textContent();
        $actions_ref->{$object}{$name}{$propertyName} = $propertyValue;
      }
    }
    $session->param("actions", $actions_ref);
    %actions = %{$actions_ref};
  }
}

my $style_sheet = <<END_STYLE_SHEET;
<!--
    body {
        background-color: #265895;
        background-image: url(/cgi-bin/gold/images/sidebar_background.gif);
        background-repeat: repeat-y;
        background-position: top right;
        margin: 0px;
        margin-top: 5px;
        padding: 0px;
    }

    h1 {
        margin: 0px;
        padding: 0px;
        padding-right: 10px;
    }

    h2 {
        text-align: center;
    }

    .sidebarHeader {
        margin: 1.2em 8px 0px;
        background-image: url(/cgi-bin/gold/images/sidebar_header_background.gif);
        background-repeat: repeat-x;
        height: 19px;
    }

    .sidebarHeader h2 {
        font-size: 80%;
        margin: 0px;
        margin-right: 5px;
        height: 14px;
        padding: 0px;
    }

    .sidebarHeader .rightFlare {
        float: right;
        width: 5px;
    }

    .sidebarSection {
        clear: both;
        margin: 0px 13px 0px 8px;
    }

    label {
        color: #B4CEEE;
        font-size: 75%;
        font-weight: bold;
        display: block;
        margin: .5em 0px 2px 2px;
    }

    select {
        font-size: 75%;
        margin-left: 2px;
    }

    h3 {
        background-color: #A5C1E4;
        color: #163E6F;
        font-size: 75%;
        text-align: left;
        margin: 1px 13px 0px 8px;
        padding: 3px 6px;
        cursor: pointer;
    }

    .menuArrow {
        float: right;
        padding-top: 2px;
    }

    .menuSection {
        margin: 0px 13px 0px 8px;
        padding: 6px 7px 3px;
        border: 1px inset #364B65;
        background-color: #3A5980;
        display: none;
    }

    #UserSection {
        display: block;
    }
 
    .menuSection a:link {
        display: block;
        padding-bottom: 5px;
        color: white;
        font-size: 70%;
    }

    .menuSection a:visited {
        display: block;
        padding-bottom: 5px;
        color: white;
        font-size: 70%;
    }

-->
END_STYLE_SHEET


my $java_script = "var NavMenus = new Array(" . join(',', map "\"$_\"", sort keys %priv) . ");\n";
foreach my $object (sort keys %objects)
{
  $java_script .= "var ${object}Actions = new Array(" . join(',', map "\"$_\"", sort keys %{$actions{$object}}) . ");\n";
}
$java_script .= <<END_JAVA_SCRIPT;
function changeActionCombo(object, form){
    var actionArray;
    var found = false;
END_JAVA_SCRIPT
foreach my $object (sort keys %objects)
{
  $java_script .= <<END_JAVA_SCRIPT;
    if (object == "$object"){
        actionArray = ${object}Actions;
        found = true;
    }
END_JAVA_SCRIPT
}
$java_script .= <<END_JAVA_SCRIPT;
    if(form == 'admin')
        var actionCombo = document.adminChooserForm.myaction;
                                                                        
    for(i=actionCombo.length-1; i >= 0; i--) {
        actionCombo[i] = null;
    }
    if(!found){
        actionCombo[0] = new Option('Select an Action','');
    }
    else{
        actionCombo[0] = new Option('Select an Action','');
        for(i=0; i < actionArray.length; i++) {
            actionCombo[i+1] = new Option(actionArray[i], actionArray[i]);
        }
    }
}
                                                                        
function doAdminAction(){
  if(document.adminChooserForm.myaction.value != ""){
     document.adminChooserForm.action="adminAction.cgi";
     document.adminChooserForm.target="action";
     document.adminChooserForm.submit();
    }
}
                                                                        
function doManageAction(myobject, myaction, mytitle){
        document.chooserForm.myobject.value = myobject;
        document.chooserForm.myaction.value = myaction;
        myobject = new String(myobject).toLowerCase();
        myaction = new String(myaction).toLowerCase();
                                                                    
        if
        (
          (myaction == 'query') ||
          (myaction == 'modify') ||
          (myaction == 'delete') ||
          (myaction == 'undelete')
        ) {
          if ((myobject == 'transaction') || (myobject == 'job')) {
            document.chooserForm.action="prescreen.cgi";
          }
          else {
            document.chooserForm.action="list.cgi";
          }
        }
        else if (
          (myaction == 'balance') ||
          (myaction == 'usage') ||
          (myaction == 'statement')
        ) {
          document.chooserForm.action=myaction+".cgi";
        }
        else if (
          (myaction == 'create') ||
          (myaction == 'deposit') ||
          (myaction == 'withdraw') ||
          (myaction == 'transfer') ||
          (myaction == 'refund')
        ) {
          document.chooserForm.action="pre"+myaction+".cgi";
        }
        else {
          document.chooserForm.action="unknown.cgi";
        }

        //construct the name of the handling cgi script based on the action
        document.chooserForm.target="action";
        parent.document.title=mytitle;
        document.chooserForm.submit();
}
END_JAVA_SCRIPT

sub print_body {
  print div( { -align => "center" },
      h1( img( { -src => "/cgi-bin/gold/images/gold_logo_sidebar.gif",
                 -width => "153",
                 -height => "54",
                 -alt => "GOLD" } ) ) ),
    div( { -class => "sidebarHeader" },
      div( { -class => "rightFlare" },
        img( { -src => "/cgi-bin/gold/images/sidebar_header_flare_right.gif",
               -width => "5",
               -height => "19",
               -alt => "Manage" } ) ),
      h2("Manage") );
  foreach my $object (sort objects_by_importance keys %priv)
  {
    print h3( { -class => "menuHead",
                -id => $object,
                -onclick => "showMenu(\"$object\")" },
      img( { -src => "/cgi-bin/gold/images/menu_arrow_closed.gif",
             -class => "menuArrow",
             -id => $object . "Arrow",
             -width => "9",
             -height => "9",
             -alt => $object . "s" } ),
      $object . "s");
    my $div = "";
    foreach my $action (sort actions_by_importance keys %{$priv{$object}})
    {
      my $title = display_action($object, $action);
      $div .= a( { -href => "javascript:doManageAction(\'$object\', \'$action\', \'$title\')" }, $title);
      # If we see Account Balance, then also support Account Statement
      if ($object eq "Account" && $action eq "Balance")
      {
        my $title = display_action($object, "Statement");
        $div .= a( { -href => "javascript:doManageAction(\'$object\', \'Statement\', \'$title\')" }, $title);
      }
      # If we see Undelete Project, then also support Usage Report
      if ($object eq "Project" && $action eq "Undelete")
      {
        my $title = display_action($object, "Usage");
        $div .= a( { -href => "javascript:doManageAction(\'$object\', \'Usage\', \'$title\')" }, $title);
      }
    }
    print div( { -class => "menuSection",
                 -id => $object . "Section" },
      $div );
  }
  print start_form( { -name  => "chooserForm",
                      -target => "action",
                      -method  => "post" } ),
    input( { -type  => "hidden",
             -name => "myobject",
             -id => "myobject" } ),
    input( { -type  => "hidden",
             -name => "myaction",
             -id => "myaction" } ),
    end_form();
  if (0) # if ($isadmin)
  {
    print div( { -class => "sidebarHeader" },
      div( { -class => "rightFlare" },
        img( { -src => "/cgi-bin/gold/images/sidebar_header_flare_right.gif",
               -width => "5",
               -height => "19",
               -alt => "Advanced" } ) ),
        h2("Advanced") );
    my $objectLabel = <<END_OBJECT_LABEL;
  <label for="myobject">Object:</label>
END_OBJECT_LABEL
    my $objectSelect = <<END_OBJECT_SELECT;
  <select name="myobject" id="myobject" onclick="changeActionCombo(this[selectedIndex].text, 'admin')">
    <option>Select an Option</option>
END_OBJECT_SELECT
    foreach my $object (sort keys %objects)
    {
      $objectSelect .= "<option>$object</option>\n";
    }
    $objectSelect .= "</select>";
    my $actionLabel = <<END_ACTION_LABEL;
  <label for="myaction">Action:</label>
END_ACTION_LABEL
    my $actionSelect = <<END_ACTION_SELECT;
  <select name="myaction" id="myaction" onclick="doAdminAction()">
    <option value=''>Select an Action</option>
  </select>
END_ACTION_SELECT
    print div( { -class => "sidebarSection" },
      start_form( { -name  => "adminChooserForm",
                      -action => "adminAction.cgi",
                      -target => "action",
                      -method  => "post" } ),
      $objectLabel,
      $objectSelect,
      $actionLabel,
      $actionSelect,
      end_form() );
    #input( { -type  => "hidden",
    #         -name => "myobject",
    #         -id => "myobject" } ),
    #input( { -type  => "hidden",
    #         -name => "myaction",
    #         -id => "myaction" } ),
    #end_form();
  }
  print br, div( { -align => "center" },
    start_form( { -name  => "logoutForm",
                  -action => "logout.cgi",
                  -target => "action",
                  -method  => "post" } ),
    input( { -type => "submit",
             -name => "logout",
             -value => "Logout",
             -style => "background-color: #EFEBAB"} ),
    end_form() );
}

sub instance_generality
{
  my ($instance) = @_;
                                                                                
  if ($instance eq "ANY") { return 4; }
  elsif ($instance eq "MEMBERS") { return 3; }
  elsif ($instance eq "ADMIN") { return 2; }
  elsif ($instance eq "SELF") { return 1; }
  else { return 1; }
}

my %object_importance = (
  "User" => -11,
  "Project" => -10,
  "Machine" => -9,
  "Account" => -8,
  "Allocation" => -7,
  "Reservation" => -6,
  "Quotation" => -5,
  "Job" => -4,
  "ChargeRate" => -3,
  "Role" => -2,
  "Transaction" => -1,
);

sub objects_by_importance
{
  return ((defined($object_importance{$a})?$object_importance{$a}:0) <=> (defined($object_importance{$b})?$object_importance{$b}:0)) || ($a cmp $b);
}

my %action_importance = (
  "Create" => -13,
  "Query" => -12,
  "Balance" => -11,
  "Deposit" => -10,
  "Withdraw" => -9,
  "Transfer" => -8,
  "Charge" => -7,
  "Reserve" => -6,
  "Quote" => -5,
  "Refund" => -4,
  "Modify" => -3,
  "Delete" => -2,
  "Undelete" => -1,
);

sub actions_by_importance
{
  return ((defined($action_importance{$a})?$action_importance{$a}:0) <=> (defined($action_importance{$b})?$action_importance{$b}:0)) || ($a cmp $b);
}

sub display_action
{
  my ($object, $action) = @_;

  if ($action eq "Query") { return "List ${object}s"; }
  elsif ($action eq "Create") { return "$action New $object"; }
  elsif ($action eq "Modify" || $action eq "Delete" || $action eq "Undelete" || $action eq "Refund" || $action eq "Charge")
  {
    return "$action $object";
  }
  elsif ($action eq "Deposit") { return "Make Deposit"; }
  elsif ($action eq "Withdraw") { return "Make Withdrawal"; }
  elsif ($action eq "Transfer") { return "Make Transfer"; }
  elsif ($action eq "Quote") { return "Issue Quote"; }
  elsif ($action eq "Reserve") { return "Make Reservation"; }
  elsif ($action eq "Balance") { return "Display Balance"; }
  elsif ($action eq "Statement") { return "Display Statement"; }
  elsif ($action eq "Usage") { return "Usage Report"; }
  else { return "$action ${object}s"; }
}

print header;
print start_html(-title => "Gold Navigation Menu",
                 -style => { -src => "/cgi-bin/gold/styles/gold.css",
                             -code => $style_sheet },
                 -script => [ { -code => $java_script },
                              { -src => "/cgi-bin/gold/scripts/menus.js" } ],
                 -onLoad => 'showMenu("User")'
  );
print_body();
print end_html;

