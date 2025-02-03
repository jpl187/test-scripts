#!/usr/bin/perl
use strict;
use warnings;

my $cpu_threshold = 20;  # CPU usage threshold in percentage
my $duration = 7200;     # Duration in seconds (2 hours)
my $command = "bdavclient-cli --scan=/";
my $log_file = "/var/log/bdav_scan.log";
my $last_run_file = "/var/run/bdav_scan_last_run";

# Check if the script has already run today
if (-e $last_run_file) {
    my $last_run_time = (stat($last_run_file))[9];
    my $current_time = time;
    if (($current_time - $last_run_time) < 86400) {
        exit 0;  # Exit if the script has already run today
    }
}

my $start_time = time;
my $low_cpu_duration = 0;

while (1) {
    my $cpu_usage = get_cpu_usage();
    
    if ($cpu_usage < $cpu_threshold) {
        $low_cpu_duration += 5;  # Check every 5 seconds
    } else {
        $low_cpu_duration = 0;
    }

    if ($low_cpu_duration >= $duration) {
        system($command);
        log_message("Command executed: $command");
        system("touch $last_run_file");
        last;
    }

    sleep 5;
}

sub get_cpu_usage {
    open my $stat_fh, '<', '/proc/stat' or die "Can't open /proc/stat: $!";
    my @cpu_stats = split ' ', <$stat_fh>;
    close $stat_fh;

    my ($user, $nice, $system, $idle) = @cpu_stats[1..4];
    my $total = $user + $nice + $system + $idle;
    my $idle_percent = $idle / $total * 100;

    return 100 - $idle_percent;
}

sub log_message {
    my ($message) = @_;
    open my $log_fh, '>>', $log_file or die "Can't open log file: $!";
    print $log_fh scalar(localtime), " - $message\n";
    close $log_fh;
}
