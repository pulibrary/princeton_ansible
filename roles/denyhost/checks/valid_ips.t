#!/usr/bin/env perl
# Before running, do the following to install dependencies:
# cpan -T Test::More Net::IP List::Util FindBin

use strict;
use warnings;
use Test::More tests => 2;
use Net::IP;
use List::Util qw/any/;
use FindBin;

sub is_local_address {
    my $ip = Net::IP->new(shift);
    my @local_ranges = (
        new Net::IP('10/8'),
        new Net::IP('172.16/12'),
        new Net::IP('192.168/16')
    );
    return unless $ip;
    return any { $ip->overlaps($_) } @local_ranges;
}

sub can_deny_ip {
    !is_local_address(shift);
}

sub ip_range_from_line {
    shift =~ /^\s*\-\s*([\d\.\/]+)/;
    return $1;
}

subtest 'denyhost list is valid', sub {
    my $file = "$FindBin::Bin/../vars/main.yml";
    open my $fh, $file or die "Could not open $file: $!";

    while( my $line = <$fh>)  {
        my $ip = ip_range_from_line($line);
        if ($ip) {
            diag "Checking $ip";
            ok(can_deny_ip($ip), "IP $ip can be blocked");
        }
    }
    close $fh;
};

subtest 'coherence checks', sub {
    plan tests => 5;
    ok can_deny_ip('5.255.231.73'), 'It can deny a crawler';
    ok !can_deny_ip('192.168.0.1'), 'It cannot deny an IP addresses in the RFC 1918 range';
    is ip_range_from_line('      - 122.234.0.0/16'),
        '122.234.0.0/16',
        'It can parse a line containing an IP address';
    is ip_range_from_line(' #     - 122.234.0.0/16'),
        undef,
        'It does not parse a commented line';
    is ip_range_from_line('- name: AS4808 China Unicom Beijing Province Network | (Description See Ticket TASK0129270)'),
        undef,
        'It does not parse ticket numbers or other non-IP numeric data';
}

