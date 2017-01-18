#! /usr/bin/perl -wT
################################################################################
#
# Modify Action Frame for Gold Web GUI
#
# File   :  modify.cgi
# History:  11 JULY 2005 [Scott Jackson] first implementation
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
my @changes = split /,/, $cgi->param("changes");
my $objects_ref = $session->param("objects");
my %objects = %{$objects_ref};
my $actions_ref = $session->param("actions");
my %actions = %{$actions_ref};
my $attributes_ref = $session->param("attributes");
my %attributes = %{$attributes_ref};

#open FILE, ">>/tmp/file";
#my @params = $cgi->param;
#foreach my $name (@params)
#{
#  print FILE "param: $name => ", $cgi->param($name), "\n";
#}
#foreach my $name (@creations) { print FILE "creation => $name\n"; }
#foreach my $name (@deletions) { print FILE "deletion => $name\n"; }
#foreach my $name (@modifications) { print FILE "modification => $name\n"; }

# Build the base modify request
my $request = new Gold::Request(object => $object, action => "Modify", actor => $username);
my $message = "";
my $data;
  
my $keyValue = "";
foreach my $condition (split /,/, $conditions)
{
  my ($name, $value) = split /=/, $condition;
  $request->setCondition($name, $value);
  $keyValue ||= $value;
}
  
# Only invoke the base modify if there are any changes to the base object
if (@changes)
{
  foreach my $name (@changes)
  {
    if ($name =~ /Assignment/)
    {
      $name =~ s/Assignment//;
      $request->setAssignment($name, $cgi->param("${name}Assignment"));
    }
  }
  
  # Issue the modify
  my $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
  $messageChunk->setRequest($request);
  my $replyChunk = $messageChunk->getChunk();
  my $response = $replyChunk->getResponse();
  my $status = $response->getStatus();
  $message = $response->getMessage();
  $data = $response->getDataElement();
  my $count = $response->getCount();
  my $doc = XML::LibXML::Document->new();
  $doc->setDocumentElement($data);
}

# Modify the associated members

# Build up a list of associations from %objects
my @associations = ();
foreach my $name (sort keys %objects)
{
  if ($objects{$name}{"Association"} eq "True" && $objects{$name}{"Parent"} eq $object && $actions{$name}{"Query"}{"Display"} eq "True")
  {
    push @associations, $name;
  }
}
                                                                                
my $createCount = 0;
my $deleteCount = 0;
my $modifyCount = 0;
if (@associations)
{
  # Iterate over all associations
  foreach my $association (@associations)
  {
    my $child = $objects{$association}{"Child"};

    my @creations = split /,/, $cgi->param("${child}Creations");
    my @deletions = split /,/, $cgi->param("${child}Deletions");
    my @modifications = split /,/, $cgi->param("${child}Modifications");

    # We must uniquify the list of modifications
    my %seen = ();
    my @semiUniqueMods = ();
    @semiUniqueMods = grep { ! $seen{$_}++ } @modifications;
    # Next, we eliminate creations
    %seen = ();
    my @quasiUniqueMods = ();
    @seen{@creations} = ();
    foreach my $item (@semiUniqueMods)
    {
      push(@quasiUniqueMods, $item) unless exists $seen{$item};
    }
    # Finally, we eliminate deletions
    %seen = ();
    my @uniqueMods = ();
    @seen{@deletions} = ();
    foreach my $item (@quasiUniqueMods)
    {
      push(@uniqueMods, $item) unless exists $seen{$item};
    }
    @modifications = @uniqueMods;

    # Obtain child primary key
    my $key = "";
    foreach my $name (sort { $attributes{$child}{$a}{Sequence} <=> $attributes{$child}{$b}{Sequence} } keys %{$attributes{$child}})
    {
      my $hidden = $attributes{$child}{$name}{Hidden};
      my $primaryKey = $attributes{$child}{$name}{PrimaryKey};
                                                                              
      next if $hidden eq "True";
      if ($primaryKey eq "True")
      {
        $key ||= $name;
      }
    }

    # Handle the association creations
    foreach my $creation (@creations)
    {
      # Create the new member
      my $request = new Gold::Request(object => $association, action => "Create", actor => $username);
      $request->setAssignment($object, $keyValue);
      $request->setAssignment($key, $creation);
      foreach my $name (keys %{$attributes{$association}})
      {
        my $hidden = $attributes{$association}{$name}{Hidden};
        my $dataType = $attributes{$association}{$name}{DataType};
        next if $hidden eq "True";
        next if $name eq $object; # We don't want the parent key
    
        my $value = $cgi->param("${creation}${child}${name}");
        if (defined $value)
        {
          $request->setAssignment($name, $value);
        }
        elsif($dataType eq "Boolean")
        {
          $request->setAssignment($name, "False");
        }
      }
  
      # Issue the create
      my $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
      $messageChunk->setRequest($request);
      my $replyChunk = $messageChunk->getChunk();
      my $response = $replyChunk->getResponse();
      my $status = $response->getStatus();
      my $message = $response->getMessage();
      my $data = $response->getDataElement();
      my $count = $response->getCount();
    
      $createCount += $count if $count > 0;
    }

    # Handle the association deletions
    foreach my $deletion (@deletions)
    {
      # Delete the member
      my $request = new Gold::Request(object => $association, action => "Delete", actor => $username);
      $request->setCondition($object, $keyValue);
      $request->setCondition($key, $deletion);
  
      # Issue the delete
      my $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
      $messageChunk->setRequest($request);
      my $replyChunk = $messageChunk->getChunk();
      my $response = $replyChunk->getResponse();
      my $status = $response->getStatus();
      my $message = $response->getMessage();
      my $data = $response->getDataElement();
      my $count = $response->getCount();
    
      $deleteCount += $count if $count > 0;
    } 

    # Handle the association modifications
    foreach my $modification (@modifications)
    {
      # Modify the member
      my $request = new Gold::Request(object => $association, action => "Modify", actor => $username);
      $request->setCondition($object, $keyValue);
      $request->setCondition($key, $modification);
      foreach my $name (keys %{$attributes{$association}})
      {
        my $hidden = $attributes{$association}{$name}{Hidden};
        my $dataType = $attributes{$association}{$name}{DataType};
        next if $hidden eq "True";
        next if $name eq $object; # We don't want the parent key
    
        my $value = $cgi->param("${modification}${child}${name}");
        if (defined $value)
        {
          $request->setAssignment($name, $value);
        }
        elsif($dataType eq "Boolean")
        {
          $request->setAssignment($name, "False");
        }
      }
    
      # Issue the modify
      my $messageChunk = new Gold::Chunk(tokenType => $TOKEN_PASSWORD, tokenName => $username, tokenValue => "$password");
      $messageChunk->setRequest($request);
      my $replyChunk = $messageChunk->getChunk();
      my $response = $replyChunk->getResponse();
      my $status = $response->getStatus();
      my $message = $response->getMessage();
      my $data = $response->getDataElement();
      my $count = $response->getCount();
    
      $modifyCount += $count if $count > 0;
    }
  }
}

# Javascript section
my $java_script = <<END_JAVA_SCRIPT;
  function updateStatus(statusInfo) {
    if (statusInfo) {
      parent.statusbar.document.location="status.cgi?" + statusInfo;
    }
    document.resultsForm.submit();
  }

END_JAVA_SCRIPT

# Build status info
my @statusInfo = ();
my @messages = ();
if ($message)
{
  $message = join '. ', split /\n/, $message; # Eliminate carriage returns
  push @messages, $message;
}
push @messages, "Successfully created $createCount associations" if $createCount;
push @messages, "Successfully deleted $deleteCount associations" if $deleteCount;
push @messages, "Successfully modified $modifyCount associations" if $modifyCount;
if (@messages)
{
  push @statusInfo, "message=" . join('. ', @messages);
}
if ($data)
{
  push @statusInfo, "data=" . $data->toString();
}
my $statusInfo = join '&', @statusInfo;

# We need a form here so we can pass myobject and myaction to the action refresh
print header;
print start_html(-title => "Modify $object",
                 -script => { -code => $java_script },
                 -onLoad => "updateStatus(\"$statusInfo\");"
);
print start_form( { -name  => "resultsForm",
                    -target => "action",
                    -action => "list.cgi",
                    -method  => "post" } ),
  input( { -type  => "hidden",
           -name => "myobject",
           -id => "myobject",
            -value => "$object" } ),
  input( { -type  => "hidden",
           -name => "myaction",
           -id => "myaction",
            -value => "$action" } ),
  end_form();
print end_html;

