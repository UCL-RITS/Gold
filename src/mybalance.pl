#! /usr/bin/perl -wT

use strict;
use FindBin qw($Bin);
use lib qw (/home/mscf/gold/lib /home/mscf/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);

# Parse Command Line Arguments
my ($help, $man, $hours, $units);
GetOptions(
    'hours|h' => \$hours,
    'help|?'  => \$help,
    'man'     => \$man,
) or pod2usage(2);

# Display usage if necessary
pod2usage(0) if $help;
if ($man)
{
    if ($< == 0)    # Cannot invoke perldoc as root
    {
        my $id = eval { getpwnam("nobody") };
        $id = eval { getpwnam("nouser") } unless defined $id;
        $id = -2                          unless defined $id;
        $<  = $id;
    }
    $> = $<;                         # Disengage setuid
    $ENV{PATH} = "/bin:/usr/bin";    # Untaint PATH
    delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
    if ($0 =~ /^([-\/\w\.]+)$/) { $0 = $1; }    # Untaint $0
    else { die "Illegal characters were found in \$0 ($0)\n"; }
    pod2usage(-exitstatus => 0, -verbose => 2);
}

# Find out who is running this command
my $user = (getpwuid($<))[0];

# The following is done for security reasons
if ($user =~ /^([-\w]+)$/) { $user = $1; }
else { die "Illegal characters were found in uid ($user)\n"; }
if ($Bin =~ /^([-\/\w\.]+)$/) { $Bin = $1; }
else { die "Illegal characters were found in path ($Bin)\n"; }
$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

# Run semi-equivalent gbalance command
open GBALANCE, "$Bin/gbalance -u $user --show Project,Machines,Balance |";

my @lines = <GBALANCE>;
if (@lines)
{
    # Munge header
    #if ($hours) { $units = "Processor Hours"; }
    #else { $units = "Processor Seconds"; }
    my $header = shift @lines;
    #$header =~ s/Projects/Account:/;
    #$header =~ s/Balance/Available ($units)/;
    print $header;
    print shift @lines;    # Print dashes

    # We basically need to do a Sum(Amount) GroupBy(Projects, Machines)

    # So we iterate over the lines, populating a sum hash
    # (aggregating shared and dedicated user amounts)
    # and a format hash as a lazy way to remember proper spacing
    my %sum    = ();
    my %format = ();
    foreach my $line (@lines)
    {
        my ($projects, $machines, $amount) = split /\s+/, $line;
        $sum{$projects}{$machines} += $amount;
        $format{$projects}{$machines} ||= $line;
    }

    # Then we iterate over the sum hash using the format
    # line as a guide and replacing the amount with our sum
    foreach my $projects (sort keys %sum)
    {
        foreach my $machines (keys %{$sum{$projects}})
        {
            my $line         = $format{$projects}{$machines};
            my $formattedSum = $sum{$projects}{$machines};
            if ($hours)
            {
                $formattedSum = sprintf("%.2f", $formattedSum / 3600);
            }
            $line =~ s/\-?\d+(?:[\.\d]*) *$/$formattedSum/;
            print $line;
        }
    }
}

##############################################################################

__END__

=head1 NAME

mybalance - display personal balance information

=head1 SYNOPSIS

B<mybalance> [B<-h>, B<--hours>] [B<-?>, B<--help>] [B<--man>]

=head1 DESCRIPTION

B<mybalance> is used to display balance information for the invoking user.

=head1 OPTIONS

=over 4

=item B<-h | --hours>

displays balance in processor-hours (instead of processor-seconds)

=item B<-? | --help>

brief help message

=item B<--man>

full documentation

=back

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

