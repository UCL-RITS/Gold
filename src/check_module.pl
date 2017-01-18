#!/usr/bin/perl

use strict;

my $dist = shift;
$dist =~ /([-\w\.]+)\-([\d\.]+\w*)/;
my ($module, $version) = ($1, $2);
$module  =~ s/CGI.pm/CGI/;    # CGI breaks naming conventions
$module  =~ s/-/::/g;
$version =~ s/_\w+$//;
$version =~ s/[A-z]//g;

print "Checking for $module $version ... ";
eval "use $module $version";
if (
    $@
    && (
        $module ne "Term::ReadLine::Gnu"
        || (   $@ !~ /Term::ReadLine::Stub/
            && $@ !~ /It is invalid to load Term::ReadLine::Gnu directly/)
    )
  )
{
    print "Not Installed\n";
    exit 0;
}
else
{
    print "Installed\n";
    exit 1;
}

