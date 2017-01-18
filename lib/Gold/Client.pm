#! /usr/bin/perl -wT
################################################################################
#
#  Gold client helper routines
#
# File   :  Client.pm
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

Gold::Client - helper routines for Gold clients

=head1 DESCRIPTION

The B<Gold::Client> module defines routines for Gold clients

=head1 METHODS

=over 4

=item parseSupplement( $name, $value );

=item $buildSupplements( $request );

=item $displayResponse( $response );

=back 

=head1 EXAMPLES

use Gold::Client;

Gold::CLient::parseSupplement();

Gold::Client::buildSupplements( $request );

Gold::Client::displayResponse( $response );

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Client;

use vars qw($log @ARGV %supplement $quiet $raw $time_division $verbose);
use Gold::Global;
use Log::Log4perl qw(get_logger);
use XML::LibXML;

# ----------------------------------------------------------------------------
# &authenticate()
# ----------------------------------------------------------------------------

sub authenticate
{
    my ($password) = @_;
    my ($tokenType, $actor, $token);
    # = ($Gold::TOKEN_SYMMETRIC, $actor, $Gold::AUTH_KEY);

    $tokenType = $config->get_property("security.token.type", $TOKEN_SYMMETRIC);

    # If Password is the configured security mechanism
    if ($tokenType eq $TOKEN_PASSWORD)
    {
        # If no password flag and a password file is present, use it

        # Otherwise prompt for a password

    }

    # Otherwise assume Symmetric is the configured security mechanism
    else
    {
        # If password flag is specified, prompt for a password

# Otherwise use the auth_key for symmetric security
#open AUTH_KEY, "${GOLD_HOME}/etc/auth_key" or throw Gold::Exception("422", "Unable to open auth_key file: $!");
#chomp($token = <AUTH_KEY>);
    }
}

# ----------------------------------------------------------------------------
# &parseSupplement( $name, $value )
# ----------------------------------------------------------------------------

sub parseSupplement
{
    my ($name, $value) = @_;
    my (%attributes);
    # Populate %attributes from option hash values
    while (@ARGV && $ARGV[0] =~ /^(\w+)=(([^\"]+)|\"([^\"]*)\")$/)
    {
        shift(@ARGV);
        $attributes{$1} = defined($3) ? $3 : $4;
    }
    push(@{$supplement{$name}}, \%attributes) if %attributes;
}

# ----------------------------------------------------------------------------
# $request = &buildSupplements( $request )
# ----------------------------------------------------------------------------

sub buildSupplements
{
    my ($request) = @_;

    # Process the --get options
    foreach my $hash (@{$supplement{get}})
    {
        if (keys %{$hash})
        {
            my $selection = new Gold::Selection(%{$hash});
            if ($log->is_debug())
            {
                $log->debug("Adding selection to request ("
                      . $selection->toString()
                      . ").");
            }
            $request->setSelection($selection);
        }
    }

    # Process the --set options
    foreach my $hash (@{$supplement{set}})
    {
        if (keys %{$hash})
        {
            my $assignment = new Gold::Assignment(%{$hash});
            if ($log->is_debug())
            {
                $log->debug("Adding assignment to request ("
                      . $assignment->toString()
                      . ").");
            }
            $request->setAssignment($assignment);
        }
    }

    # Process the --where options
    foreach my $hash (@{$supplement{where}})
    {
        if (keys %{$hash})
        {
            my $condition = new Gold::Condition(%{$hash});
            if ($log->is_debug())
            {
                $log->debug("Adding condition to request ("
                      . $condition->toString()
                      . ").");
            }
            $request->setCondition($condition);
        }
    }

    # Process the --option options
    foreach my $hash (@{$supplement{option}})
    {
        if (keys %{$hash})
        {
            my $option = new Gold::Option(%{$hash});
            if ($log->is_debug())
            {
                $log->debug(
                    "Adding option to request (" . $option->toString() . ").");
            }
            $request->setOption($option);
        }
    }

    # Process the --job data
    foreach my $hash (@{$supplement{job}})
    {
        my $job = new Gold::Datum("Job");
        foreach my $property (keys %{$hash})
        {
            $job->setValue($property, ${$hash}{$property});
        }
        if ($log->is_debug())
        {
            $log->debug(
                "Adding job data to request (" . $job->toString() . ").");
        }
        $request->setDatum($job);
    }

    return $request;
}

# ----------------------------------------------------------------------------
# &displayResponse( $response )
# ----------------------------------------------------------------------------

sub displayResponse
{
    my ($response) = @_;
    if ($log->is_debug())
    {
        $log->debug("Displaying response");
    }

    my $status      = $response->getStatus();
    my $message     = $response->getMessage();
    my $chunkNum    = $response->getChunkNum();
    my $doc         = XML::LibXML::Document->new();
    my $dataElement = $response->getDataElement();
    $doc->setDocumentElement($dataElement);

    # Print data for query or if verbose
    if ($verbose)
    {
        if ($dataElement)
        {
            my @data = $dataElement->childNodes();
            if (@data)
            {
                my $currency_precision;
                if ($time_division == 3600)
                {
                    $currency_precision = 2;
                }
                else
                {
                    $currency_precision =
                      $config->get_property("currency.precision") || 0;
                    if ($currency_precision =~ /^(\d+)$/)
                    {
                        $currency_precision = $1;
                    }
                    else
                    {
                        die
                          "Illegal characters were found in \$currency_precision ($currency_precision)\n";
                    }
                }

                # Raw format
                if ($raw)
                {
                    my $firstField;
                    # Print header if there is any data and not quiet
                    if (! $quiet && $data[0] && $chunkNum == 1)
                    {
                        my @fields = $data[0]->childNodes();
                        $firstField = 1;
                        foreach my $field (@fields)
                        {
                            if ($firstField) { $firstField = 0; }
                            else             { print "|"; }
                            print $field->nodeName();
                        }
                        print "\n";
                    }
                    # Print data
                    foreach my $data (@data)
                    {
                        my @fields = $data->childNodes();
                        $firstField = 1;
                        foreach my $field (@fields)
                        {
                            if ($firstField) { $firstField = 0; }
                            else             { print "|"; }
                            my $name  = $field->nodeName();
                            my $value = $field->textContent();
                            if (
                                $value ne ""
                                && (   $name eq "Delta"
                                    || $name eq "CreditLimit"
                                    || $name eq "Amount"
                                    || $name eq "Deposited"
                                    || $name eq "Charge"
                                    || $name eq "Balance"
                                    || $name eq "Reserved"
                                    || $name eq "Available")
                              )
                            {
                                $value = sprintf("%.${currency_precision}f",
                                    $value / $time_division);
                            }
                            print $value;
                        }
                        print "\n";
                    }
                }
                # Cooked format
                else
                {
                    my %size = ();
                    # Determine column widths
                    my @fields = $data[0]->childNodes();
                    foreach my $field (@fields)
                    {
                        my $name = $field->nodeName();
                        $size{$name} = length($name);
                    }
                    foreach my $data (@data)
                    {
                        my @fields = $data->childNodes();
                        foreach my $field (@fields)
                        {
                            my $name  = $field->nodeName();
                            my $value = $field->textContent();
                            if (
                                $value ne ""
                                && (   $name eq "Delta"
                                    || $name eq "CreditLimit"
                                    || $name eq "Amount"
                                    || $name eq "Deposited"
                                    || $name eq "Charge"
                                    || $name eq "Balance"
                                    || $name eq "Reserved"
                                    || $name eq "Available")
                              )
                            {
                                $value = sprintf("%.${currency_precision}f",
                                    $value / $time_division);
                            }
                            $size{$name} = length($value)
                              if length($value) > $size{$name};
                        }
                    }
                    # Print header if there is any data and not quiet
                    if (! $quiet && $data[0])
                    {
                        my @fields = $data[0]->childNodes();
                        foreach my $field (@fields)
                        {
                            my $name = $field->nodeName();
                            printf "%-$size{$name}s ", $name;
                        }
                        print "\n";
                        foreach my $field (@fields)
                        {
                            my $name = $field->nodeName();
                            printf "%-$size{$name}s ", "-" x $size{$name};
                        }
                        print "\n";
                    }
                    # Print data
                    foreach my $data (@data)
                    {
                        my @fields = $data->childNodes();
                        foreach my $field (@fields)
                        {
                            my $name  = $field->nodeName();
                            my $value = $field->textContent();
                            if (
                                $value ne ""
                                && (   $name eq "Delta"
                                    || $name eq "CreditLimit"
                                    || $name eq "Amount"
                                    || $name eq "Deposited"
                                    || $name eq "Charge"
                                    || $name eq "Balance"
                                    || $name eq "Reserved"
                                    || $name eq "Available")
                              )
                            {
                                printf("%$size{$name}.${currency_precision}f ",
                                    $value / $time_division);
                            }
                            else
                            {
                                printf("%-$size{$name}s ", $value);
                            }
                        }
                        print "\n";
                    }
                }
            }
        }
    }

    # Print message if not quiet or not successfull
    if ($message && (! $quiet || $status ne "Success")) { print "$message\n"; }
}

# ----------------------------------------------------------------------------
# &enableDebug( $name, $value )
# ----------------------------------------------------------------------------

sub enableDebug
{
    my ($name, $value) = @_;

    my $screenAppender =
      new Log::Log4perl::Appender("Log::Log4perl::Appender::Screen",);
    my $layout = new Log::Log4perl::Layout::PatternLayout(
        "%d{yyyy-MM-dd HH:mm:ss.SSS} %-5p %M [%F:%L]  %m%n");
    $screenAppender->layout($layout);
    if ($value)
    {
        $screenAppender->threshold($value);
    }
    else
    {
        $screenAppender->threshold("TRACE");
    }

    $log->add_appender($screenAppender);
}

1;
