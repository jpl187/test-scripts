#!/usr/bin/perl
use strict;
use warnings;
use YAML::Tiny;
use File::Find;
use File::stat;
use Time::Piece;

my @directories = ("/var/backups/", "/home/username/Downloads/", "/var/cache/");
my $size_file = "/var/log/test-3/dir_sizes.yaml";
my $log_file = "/var/log/test-3/scan_log.yaml";

# Function to calculate the total size of a directory
sub calculate_size {
    my ($dir) = @_;
    my $total_size = 0;

    find(sub { $total_size += -s if -f }, $dir);

    return $total_size;
}

# Function to write sizes to YAML file
sub write_size_to_yaml {
    my ($sizes) = @_;
    my $yaml = YAML::Tiny->new;
    $yaml->[0] = { map { $_ => "$sizes->{$_} bytes" } keys %$sizes };
    $yaml->write($size_file);
}

# Function to log output to YAML file
sub log_output {
    my ($message) = @_;
    my $timestamp = localtime->strftime('%Y-%m-%d %H:%M:%S');
    my $log_entry = { timestamp => $timestamp, message => $message };

    my $yaml;
    if (-e $log_file) {
        $yaml = YAML::Tiny->read($log_file);
    } else {
        $yaml = YAML::Tiny->new;
    }
    push @{$yaml->[0]}, $log_entry;
    $yaml->write($log_file);
}

# Read the previous sizes from YAML file
my %previous_sizes;
if (-e $size_file) {
    my $yaml = YAML::Tiny->read($size_file);
    %previous_sizes = map { $_ => $yaml->[0]->{$_} =~ s/ bytes$//r } keys %{$yaml->[0]};
}

# Calculate the current sizes
my %current_sizes;
foreach my $dir (@directories) {
    $current_sizes{$dir} = calculate_size($dir);
}

# Check if sizes have changed and scan only changed directories
my $scanned = 0;
foreach my $dir (@directories) {
    if (!exists $previous_sizes{$dir} || $previous_sizes{$dir} != $current_sizes{$dir}) {
        system("gdavclient-cli scan=$dir > scan_output.log 2>&1");
        open my $fh, '<', 'scan_output.log';
        my $scan_output = do { local $/; <$fh> };
        close $fh;
        log_output("Size of $dir changed. Performed virus scan. Output: $scan_output");
        $scanned = 1;
    }
}

# Update the sizes in the YAML file if any scan was performed
if ($scanned) {
    write_size_to_yaml(\%current_sizes);
} else {
    log_output("No directory sizes have changed. Skipping virus scan.");
}
