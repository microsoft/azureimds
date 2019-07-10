#!/usr/bin/env perl

use strict;
use warnings;
use LWP::UserAgent;
use JSON;

my @header = ('Metadata' => 'True');
my $browser = LWP::UserAgent->new();   
my $response = $browser->get('http://169.254.169.254/metadata/instance?api-version=2019-04-30', @header);  # call HTTP get
my $resStr = $response->content;
my $json = JSON->new;
print $json->pretty->encode($json->decode($resStr));