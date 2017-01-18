#! /usr/bin/perl -wT
################################################################################
#
# Create Action Frame for Gold Web GUI
#
# File   :  create.cgi
# History:  14 JUN 2005 [Scott Jackson] first implementation
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

# Build the create request
my $request = new Gold::Request(object => $object, action => "Create", actor => $username);

foreach my $name (keys %{$attributes{$object}})
{
  if ($cgi->param("${name}Assignment"))
  {
    $request->setAssignment($name, $cgi->param("${name}Assignment"));
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
my $doc = XML::LibXML::Document->new();
$doc->setDocumentElement($data);

#open FILE, ">>/tmp/file";
#my @names = $cgi->param;
#foreach my $name (@names)
#{
#  print FILE "$name => ", $cgi->param("$name"), "\n";
#}

# Create the associated members

# Build up a list of associations from %objects
my @associations = ();
foreach my $name (sort keys %objects)
{
  if ($objects{$name}{"Association"} eq "True" && $objects{$name}{"Parent"} eq $object && $actions{$name}{"Query"}{"Display"} eq "True")
  {
    push @associations, $name;
  }
}
                                                                                
my $assCount = 0;
if (@associations)
{
  # Extract the primary key value if creating associations
  my $primaryKeyName = "Name";
  foreach my $name (keys %{$attributes{$object}})
  {
    if ($attributes{$object}{$name}{"PrimaryKey"} eq "True")
    {
      $primaryKeyName = $name;
      last;
    }
  }
  my $primaryKeyValue = $response->getDatumValue($primaryKeyName);

  # Iterate over all associations
  foreach my $association (@associations)
  {
    my $child = $objects{$association}{"Child"};
    my @members = ();
    foreach my $name (keys %{$attributes{$association}})
    {
      my $hidden = $attributes{$association}{$name}{Hidden};
      next if $hidden eq "True";
      next if $name eq $object; # We don't want the parent key
      
      my @values = split /,/, $cgi->param("${object}${child}${name}");
      for (my $i = 0; $i < @values; $i++)
      {
        $members[$i]->{$name} = $values[$i];
      }
    }
  

    # Iterate over the members
    foreach my $member (@members)
    {
      # Create the member
      my $request = new Gold::Request(object => $association, action => "Create", actor => $username);
      $request->setAssignment($object, $primaryKeyValue);
      foreach my $name (keys %{$member})
      {
        $request->setAssignment($name, $member->{$name});
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
    
      $assCount += $count if $count;
    } 
  }
}

# Javascript section
my $java_script = <<END_JAVA_SCRIPT;
  function updateStatus(statusInfo) {
    if (statusInfo) {
      parent.statusbar.document.location="status.cgi?" + statusInfo;
      document.resultsForm.submit();
    }
  }

END_JAVA_SCRIPT

my @statusInfo = ();
if ($message)
{
  if ($assCount) { $message .= "\nSuccessfully created $assCount associations"; }
  $message = join '. ', split /\n/, $message; # Eliminate carriage returns
  push @statusInfo, "message=$message";
}
push @statusInfo, "data=" . $data->toString();
my $statusInfo = join '&', @statusInfo;

# We need a form here so we can pass myobject and myaction to the action refresh
print header;
print start_html(-title => "Create New $object",
                 -script => { -code => $java_script },
                 -onLoad => "updateStatus(\"$statusInfo\");"
);
print start_form( { -name  => "resultsForm",
                    -target => "action",
                    -action => "precreate.cgi",
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

