# monitor-log

This script monitors a site and url, optionally checking that it contains a string value.

All output from this command is piped directly to stdout.

## Getting Started
Note: this script relies on bash. It cannot be run as sh.

1. Clone this repo (or download the [latest release](releases/latest))
1. Copy the .env.example file to .env and configure. Each configuration option is commented inline.
1. Run the command in a screen session, configure it with systemd, or run with nohup.

## Is it working?
You can check if the script is working by sending SIGUSR1 to the process. When the script starts, it politely prints out its PID along with the suggested `kill` script to send the signal. This will output a handy "It's working" along with a timestamp to stdout (so check whatever log file you're piping to).

## What does it run?
The script is designed to run debugging in under 5 seconds. Currently, it executes the following scripts (in order) with optimizations for fast running:
1. `diff` to compare the expected string to the returned string
1. `tcpdump` to show the traffic during the curl request
1. `traceroute` to show the current path to the server
1. `ping` to show if the host is up

## What will I get?
You'll get the output of these commands, along with timestamps of when things went down and when they came back up.

[Here's an example file](sample-output.txt) produced by temporarily overriding the DNS of google.com to 127.0.0.1 in my /etc/hosts file.

