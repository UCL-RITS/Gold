#! /usr/bin/perl -wT
################################################################################
#
# Refund Action Frame for Gold Web GUI
#
# File   :  refund.cgi
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
my $amount = $cgi->param("Amount");
my $description = $cgi->param("Description");
my $id = $cgi->param("Id");
my $jobId = $cgi->param("JobId");

# Build the refund request
my $request = new Gold::Request(object => "Job", action => "Refund", actor => $username);

$request->setOption("JobId", $jobId) if $jobId;
$request->setOption("Id", $id) if $id;
$request->setOption("Amount", $amount) if $amount;
$request->setOption("Description", $description) if $description;

# Issue the refund
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
  $message = join '. ', split /\n/, $message; # Eliminate carriage returns
  push @statusInfo, "message=$message";
}
push @statusInfo, "data=" . $data->toString();
my $statusInfo = join '&', @statusInfo;

# We need a form here so we can pass myobject and myaction to the action refresh
print header;
print start_html(-title => "Job Refund",
                 -script => { -code => $java_script },
                 -onLoad => "updateStatus(\"$statusInfo\");"
);
print start_form( { -name  => "resultsForm",
                    -target => "action",
                    -action => "prerefund.cgi",
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

