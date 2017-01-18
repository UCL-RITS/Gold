#! /usr/bin/perl -wT
################################################################################
#
# Gold Assignment object
#
# File   :  Assignment.pm
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

Gold::Assignment - represents an object property to be assigned

=head1 DESCRIPTION

The B<Gold::Assignment> module defines functions to build and parse Assignments

=head1 CONSTRUCTOR

my $assignment = new Gold::Assignment(name => $name[, value => $value][, op => $op]);

=head1 ACCESSORS

=over 4

=item $name = $assignment->getName();

=item $value = $assignment->getValue();

=item $op = $assignment->getOperator();

=back 

=head1 MUTATORS

=over 4

=item $assignment = $assignment->setName($name);

=item $assignment = $assignment->setValue($value);

=item $assignment = $assignment->setOperator($op);

=back

=head1 OTHER METHODS

=over 4

=item $string = $assignment->toString();

=back

=head1 EXAMPLES

use Gold::Assignment;

my $assignment1 = new Gold::Assignment(name => "Active", value => "True");
my $assignment2 = new Gold::Assignment(name => "Amount", value => "100", op => "Inc");

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Assignment;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, %arg) = @_;
    bless {
        _name => $arg{name} || "",    # SCALAR
        _value => defined $arg{value} ? $arg{value} : "",    # SCALAR
        _op => $arg{op} || "",                               # SCALAR
    }, $class;
}

# ----------------------------------------------------------------------------
# Accessors
# ----------------------------------------------------------------------------

# Get the assignment name
sub getName
{
    my ($self) = @_;
    return $self->{_name};
}

# Get the assignment value
sub getValue
{
    my ($self) = @_;
    return $self->{_value};
}

# Get the assignment operator
sub getOperator
{
    my ($self) = @_;
    return $self->{_op};
}

# ----------------------------------------------------------------------------
# Mutators
# ----------------------------------------------------------------------------

# Set the assignment name
sub setName
{
    my ($self, $name) = @_;
    $self->{_name} = $name if defined $name;
    return $self;
}

# Set the assignment value
sub setValue
{
    my ($self, $value) = @_;
    $self->{_value} = $value if defined $value;
    return $self;
}

# Set the assignment operator
sub setOperator
{
    my ($self, $op) = @_;
    $self->{_op} = $op if defined $op;
    return $self;
}

# ----------------------------------------------------------------------------
# Other Methods
# ----------------------------------------------------------------------------

# Convert assignment to printable string
sub toString
{
    my ($self) = @_;
    my ($string);
    $string = "(";
    $string .= $self->{_name};
    $string .= ", ";
    $string .= $self->{_value};
    $string .= ", ";
    $string .= $self->{_op};
    $string .= ")";
    return $string;
}

1;
