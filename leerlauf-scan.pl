#!/usr/bin/perl
use strict;
use warnings;
use Time::HiRes qw(sleep);
use POSIX qw(strftime mktime);
use YAML::Tiny;

my $check_interval = 60; # Check every minute
my $threshold_duration = 60 * 60; # 1 hour in seconds
my $monitor_start_time = "01:00:00";
my $monitor_end_time = "04:00:00";
my $cpu_usage_log = '/var/log/cpu_usage.yaml';
my $scan_log = '/var/log/scan_log.yaml';

sub get_cpu_usage {
    my $cpu_usage = `grep 'cpu ' /proc/stat`;
    my ($user, $nice, $system, $idle) = (split /\s+/, $cpu_usage)[1..4];
    my $total = $user + $nice + $system + $idle;
    return ($idle / $total) * 100;
}

sub log_to_yaml {
    my ($file, $data) = @_;
    my $yaml = YAML::Tiny->new($data);
    $yaml->write($file);
}

sub read_yaml {
    my ($file) = @_;
    return YAML::Tiny->read($file)->[0];
}

sub should_scan_today {
    my $scan_data = read_yaml($scan_log);
    my $last_scan_date = $scan_data->{date} || '';
    my $today_date = strftime "%Y-%m-%d", localtime;

    return $last_scan_date ne $today_date;
}

sub monitor_cpu {
    my ($start_time, $end_time) = @_;
    my $start_epoch = time_to_epoch($start_time);
    my $end_epoch = time_to_epoch($end_time);
    my $min_cpu_usage = 100;
    my $monitoring_start = time;
    
    while (time < $end_epoch) {
        my $cpu_usage = get_cpu_usage();
        if ($cpu_usage < $min_cpu_usage) {
            $min_cpu_usage = $cpu_usage;
            $monitoring_start = time;
        }
        if (time - $monitoring_start >= $threshold_duration) {
            my $timestamp = strftime "%Y-%m-%d %H:%M:%S", localtime($monitoring_start);
            log_to_yaml($cpu_usage_log, { timestamp => $timestamp, cpu_usage => $min_cpu_usage });
            return $timestamp;
        }
        sleep $check_interval;
    }
    return undef;
}

sub time_to_epoch {
    my ($str_time) = @_;
    my ($h, $m, $s) = split /:/, $str_time;
    my $now = time;
    my @lt = localtime($now);
    $lt[2] = $h;
    $lt[1] = $m;
    $lt[0] = $s;
    return mktime(@lt);
}

sub perform_scan {
    my ($timestamp) = @_;
    system("clamscan -r /");
    my $today_date = strftime "%Y-%m-%d", localtime;
    log_to_yaml($scan_log, { date => $today_date, scan_time => $timestamp });
}

if (should_scan_today()) {
    my $scan_time = monitor_cpu($monitor_start_time, $monitor_end_time);
    perform_scan($scan_time) if $scan_time;
}
