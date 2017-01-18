#! /usr/bin/perl -wT
################################################################################
#
# Gold Exception
#
# File   :  Exception.pm
#
################################################################################
#                                                                              #
#                           Copyright (c) 2003, 2004                           #
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

=head1 NAME

Gold::Exception - custom Gold exception

=head1 DESCRIPTION

The B<Gold::Exception> module defines a custom Gold exception
It specifies an error code followed by an explanatory message.

=head1 EXAMPLES

use Gold::Exception;

sub throwsException
{
  throw Gold::Exception("999", "Oops");
}
try
{
  throwsException();
}
catch Gold::Exception with
{
  print "Received a Gold exception ($_[0])";
};

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Exception;

use base qw(Error);
use overload('""' => 'stringify');
use vars qw($log);
use Carp qw(cluck);
use Gold::Global;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, @args) = @_;
    my %params = ();

    if ($#args >= 1)
    {
        $params{-value} ||= $args[0];
        $params{-text}  ||= $args[1];
    }
    elsif ($#args == 0)
    {
        $params{-value} ||= "999";
        $params{-text}  ||= $args[0];
    }
    else
    {
        $params{-value} ||= "999";
        $params{-text}  ||= "";
    }

    $log->error(Carp::shortmess($params{-text}));
    local $Error::Depth = $Error::Depth + 1;
    local $Error::Debug = 1;                   # Enables storing of stacktrace
    $class->SUPER::new(%params);
}

1;
