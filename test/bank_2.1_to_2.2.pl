#!/usr/bin/perl -w
use strict;

CREATE_MODIFY:
{
    print "\n***Creating new ChargeRate Instance Attribute***\n";
    my $cmd = "goldsh -v Attribute Create Object=ChargeRate Name=Instance PrimaryKey=True DataType=String DefaultValue=\"\\\"\\\"\" Description=\"\\\"Charge Rate Instance\\\"\"";
    my $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
    my $rc     = $? >> 8;
    die ("Subcommand ($cmd) failed with rc=$rc:\n$output") if $rc && $output;
    print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;
    print "\n***Creating new QuotationChargeRate Instance Attribute***\n";
    $cmd = "goldsh -v Attribute Create Object=QuotationChargeRate Name=Instance PrimaryKey=True DataType=String DefaultValue=\"\\\"\\\"\" Description=\"\\\"Charge Rate Instance\\\"\"";
    $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
    $rc     = $? >> 8;
    die ("Subcommand ($cmd) failed with rc=$rc:\n$output") if $rc && $output;
    print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;
    print "\n***Modifying ChargeRate Name Description***\n";
    $cmd = "goldsh -v Attribute Modify Object==QuotationChargeRate Name==Name Description=\"\\\"Charge Rate Name\\\"\"";
    $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
    $rc     = $? >> 8;
    die ("Subcommand ($cmd) failed with rc=$rc:\n$output") if $rc && $output;
    print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;
    print "\n***Adding Create as a Job Stage Value***\n";
    $cmd = "goldsh -v Attribute Modify Object==Job Name==Stage Values=\"\\\"(Charge,Create,Quote,Reserve)\\\"\"";
    $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
    $rc     = $? >> 8;
    die ("Subcommand ($cmd) failed with rc=$rc:\n$output") if $rc && $output;
    print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;
    print "\n***Adding Job Create Scheduler Role Action***\n";
    $cmd = "goldsh -v RoleAction Create Role=Scheduler Name=Create Object=Job";
    $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
    $rc     = $? >> 8;
    die ("Subcommand ($cmd) failed with rc=$rc:\n$output") if $rc && $output;
    print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;
}

TRANSFORM_CHARGERATES:
{
    print "\n***Translating existing ChargeRates to new format***\n";
    my $cmd = "goldsh ChargeRate Query Show:=Type,Name,Instance,Rate,Description --raw --quiet";
    my $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
    my $rc     = $? >> 8;
    ie ("Subcommand ($cmd) failed with rc=$rc:\n$output") if $rc && $output;
    print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;
    my @lines = split /\n/, $output;
    foreach my $line (@lines)
    {
        my ($type, $name, $instance, $rate, $description) = split /\|/, $line;
        if ($type eq "Resource")
        {
            my $cmd = "goldsh -v ChargeRate Create Type=VBR Name=$name Instance=\\\"\\\" Rate=$rate Description=\"\\\"$description\\\"\"";
            my $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
            my $rc     = $? >> 8;
            print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;
            unless ($rc)
            {
                my $cmd = "goldsh -v ChargeRate Delete Type==$type Name==$name";
                my $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
                my $rc     = $? >> 8;
                print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;      
            }
        }
        elsif ($type eq "Usage")
        {
            my $cmd = "goldsh -v ChargeRate Create Type=VBU Name=$name Instance=\\\"\\\" Rate=$rate Description=\"\\\"$description\\\"\"";
            my $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
            my $rc     = $? >> 8;
            print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;
            unless ($rc)
            {
                my $cmd = "goldsh -v ChargeRate Delete Type==$type Name==$name";
                my $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
                my $rc     = $? >> 8;
                print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;      
            }
        }
        elsif ($type eq "Mutiplier")
        {
            my $cmd = "goldsh -v ChargeRate Create Type=VBM Name=$name Instance=\\\"\\\" Rate=$rate Description=\"\\\"$description\\\"\"";
            my $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
            my $rc     = $? >> 8;
            print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;
            unless ($rc)
            {
                my $cmd = "goldsh -v ChargeRate Delete Type==$type Name==$name";
                my $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
                my $rc     = $? >> 8;
                print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;      
            }
        }
        else # This must be an NBM
        {
            my $cmd = "goldsh -v ChargeRate Create Type=NBM Name=$type Instance=$name Rate=$rate Description=\"\\\"$description\\\"\"";
            my $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
            my $rc     = $? >> 8;
            print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;
            unless ($rc)
            {
                my $cmd = "goldsh -v ChargeRate Delete Type==$type Name==$name";
                my $output = `$cmd 2>&1` || `sh -c "$cmd 2>&1"`;
                my $rc     = $? >> 8;
                print ("Subcommand ($cmd) returned with rc=$rc:\n$output") if $output;      
            }
        }
    }
}


