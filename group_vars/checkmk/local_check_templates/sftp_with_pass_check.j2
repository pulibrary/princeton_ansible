#!/usr/bin/env perl

{{ ansible_managed | comment }}

use strict;
use warnings;
use Net::SFTP::Foreign;
use Net::SSH2;

# Replace with your credentials and server details
my $sftp_host = "{{ host_ad_name }}";
my $sftp_user = "{{ almasftp_user }}";
my $sftp_password = "{{ almasftp_user_password }}";

# Exit codes for Checkmk
my $state_ok = 0;
my $state_warn = 1;
my $state_crit = 2;
my $state_unknown = 3;

# Create a new SSH2 object
my $ssh2 = Net::SSH2->new();

# Connect to the SFTP server
eval { $ssh2->connect($sftp_host) or die "Connection failed: $@"; };

# Handle potential exception during connection
if ($@) {
  print "$state_crit \"sftp_check\" - Connection to SFTP server $sftp_host failed: $@\n";
  exit $state_crit;
}

# Try password authentication
eval { $ssh2->auth_password($sftp_user, $sftp_password) or die "Authentication failed: $@"; };

# Handle potential exception during authentication
if ($@) {
  print "$state_crit \"sftp_check\" - Authentication to SFTP server $sftp_host failed: $@\n";
  exit $state_crit;
}

# Create a new SFTP object using the existing SSH2 connection
my $sftp = Net::SFTP::Foreign->new(ssh2 => $ssh2, backend => 'Net_SSH2');

# Check for SFTP object creation errors
if ($sftp->error) {
  print "$state_crit \"sftp_check\" - Error creating SFTP object: $sftp->error\n";
  exit $state_crit;
}

# Connection successful! (Optional: Perform some basic SFTP operation)
print "$state_ok \"sftp_check\" - Successful connection to SFTP server $sftp_host\n";

# Close the connection
$ssh2->disconnect();

exit $state_ok;
