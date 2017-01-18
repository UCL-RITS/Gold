#! /usr/bin/perl -wT
################################################################################
#
# Gold Object object
#
# File   :  Object.pm
#
################################################################################
#                                                                              #
#                              Copyright (c) 2004                              #
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

Gold::Object - represents an object

=head1 DESCRIPTION

The B<Gold::Object> module defines functions to build and parse Objects

=head1 CONSTRUCTOR

my $object = new Gold::Object(name => $name, join => $join);

=head1 ACCESSORS

=over 4

=item $name = $object->getName();

=item $join = $object->getJoin();

=back 

=head1 MUTATORS

=over 4

=item $object->setName($name);

=item $object->setJoin($join);

=back

=head1 OTHER METHODS

=over 4

=item $string = $object->toString();

=back

=head1 EXAMPLES

use Gold::Object;

my $object1 = new Gold::Object(name => "Project");

my $object2 = new Gold::Object(name => "ProjectUser", join => "LeftOuter");

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Object;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, %arg) = @_;
    bless {
        _name  => $arg{name}  || "",    # SCALAR
        _alias => $arg{alias} || "",    # SCALAR
        _join  => $arg{join}  || "",    # SCALAR
    }, $class;
}

# ----------------------------------------------------------------------------
# Accessors
# ----------------------------------------------------------------------------

# Get the object name
sub getName
{
    my ($self) = @_;
    return $self->{_name};
}

# Get the object alias
sub getAlias
{
    my ($self) = @_;
    return $self->{_alias};
}

# Get the object join
sub getJoin
{
    my ($self) = @_;
    return $self->{_join};
}

# ----------------------------------------------------------------------------
# Mutators
# ----------------------------------------------------------------------------

# Set the object name
sub setName
{
    my ($self, $name) = @_;
    $self->{_name} = $name if defined $name;
    return $self;
}

# Set the object alias
sub setAlias
{
    my ($self, $alias) = @_;
    $self->{_alias} = $alias if defined $alias;
    return $self;
}

# Set the object join
sub setJoin
{
    my ($self, $join) = @_;
    $self->{_join} = $join if defined $join;
    return $self;
}

# ----------------------------------------------------------------------------
# Other Methods
# ----------------------------------------------------------------------------

# Convert object to printable string
sub toString
{
    my ($self) = @_;
    my ($string);
    $string = "(";
    $string .= $self->{_name};
    $string .= ", ";
    $string .= $self->{_alias};
    $string .= ", ";
    $string .= $self->{_join};
    $string .= ")";
    return $string;
}

1;
