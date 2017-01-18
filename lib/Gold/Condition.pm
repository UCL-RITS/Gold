#! /usr/bin/perl -wT
################################################################################
#
#  Gold Condition object
#
# File   :  Condition.pm
#
################################################################################
#                                                                              #
#                          Copyright (c) 2003, 2004                            #
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

Gold::Condition - represents a condition upon which objects are selected

=head1 DESCRIPTION

The B<Gold::Condition> module defines functions to build and parse Conditions

=head1 CONSTRUCTOR

my $condition = new Condition(name => $name, value => $value, op => $op, conj => $conj, group => $group, object => $object, subject => $subject);

=head1 ACCESSORS

=over 4

=item $name = $condition->getName();

=item $value = $condition->getValue();

=item $op = $condition->getOperator();

=item $conj = $condition->getConjunction();

=item $group = $condition->getGroup();

=item $object = $condition->getObject();

=item $subject = $condition->getSubject();

=back 

=head1 MUTATORS

=over 4

=item $condition = $condition->setName($name);

=item $condition = $condition->setValue($value);

=item $condition = $condition->setOperator($op);

=item $condition = $condition->setConjunction($conj);

=item $condition = $condition->setGroup($group);

=item $condition = $condition->setObject($object);

=item $condition = $condition->setSubject($subject);

=back

=head1 OTHER METHODS

=over 4

=item $string = $condition->toString();

=back

=head1 EXAMPLES

use Gold::Condition;

my $condition1 = new Gold::Condition(name => "Name", value => "mscfops");

my $condition2 = new Gold::Condition(name => "Amount", value => "1024", op => "ge", conj => "Or");

my $condition3 = new Gold::Condition(object => "ProjectUser", name => "Project", subject => "Project", value => "Name");

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Condition;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, %arg) = @_;
    bless {
        _name => $arg{name} || "",    # SCALAR
        _value => defined $arg{value} ? $arg{value} : "",    # SCALAR
        _op      => $arg{op}      || "",                     # SCALAR
        _conj    => $arg{conj}    || "",                     # SCALAR
        _group   => $arg{group}   || 0,                      # SCALAR
        _object  => $arg{object}  || "",                     # SCALAR
        _subject => $arg{subject} || "",                     # SCALAR
    }, $class;
}

# ----------------------------------------------------------------------------
# Accessors
# ----------------------------------------------------------------------------

# Get the condition name
sub getName
{
    my ($self) = @_;
    return $self->{_name};
}

# Get the condition value
sub getValue
{
    my ($self) = @_;
    return $self->{_value};
}

# Get the condition operator
sub getOperator
{
    my ($self) = @_;
    return $self->{_op};
}

# Get the condition conjunction
sub getConjunction
{
    my ($self) = @_;
    return $self->{_conj};
}

# Get the condition group
sub getGroup
{
    my ($self) = @_;
    return $self->{_group};
}

# Get the condition object
sub getObject
{
    my ($self) = @_;
    return $self->{_object};
}

# Get the condition subject
sub getSubject
{
    my ($self) = @_;
    return $self->{_subject};
}

# ----------------------------------------------------------------------------
# Mutators
# ----------------------------------------------------------------------------

# Set the condition name
sub setName
{
    my ($self, $name) = @_;
    $self->{_name} = $name if defined $name;
    return $self;
}

# Set the condition value
sub setValue
{
    my ($self, $value) = @_;
    $self->{_value} = $value if defined $value;
    return $self;
}

# Set the condition operator
sub setOperator
{
    my ($self, $op) = @_;
    $self->{_op} = $op if defined $op;
    return $self;
}

# Set the condition conjunction
sub setConjunction
{
    my ($self, $conj) = @_;
    $self->{_conj} = $conj if defined $conj;
    return $self;
}

# Set the condition group
sub setGroup
{
    my ($self, $group) = @_;
    $self->{_group} = $group if defined $group;
    return $self;
}

# Set the condition object
sub setObject
{
    my ($self, $object) = @_;
    $self->{_object} = $object if defined $object;
    return $self;
}

# Set the condition subject
sub setSubject
{
    my ($self, $subject) = @_;
    $self->{_subject} = $subject if defined $subject;
    return $self;
}

# ----------------------------------------------------------------------------
# Other Methods
# ----------------------------------------------------------------------------

# Convert condition to printable string
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
    $string .= ", ";
    $string .= $self->{_conj};
    $string .= ", ";
    $string .= $self->{_group} if $self->{_group};
    $string .= ", ";
    $string .= $self->{_object};
    $string .= ", ";
    $string .= $self->{_subject};
    $string .= ")";
    return $string;
}

1;
