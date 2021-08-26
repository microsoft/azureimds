#!/usr/bin/env perl

use strict;
use warnings;

use HTTP::Tiny;
use JSON;
use Data::Dumper;

my $md_url = 'http://169.254.169.254/metadata/instance?api-version=2021-02-01';
my $headers = { Metadata => 'true' };

# Proxies must be bypassed when calling Azure IMDS
my $response = HTTP::Tiny->new(proxy => undef)->get($md_url, { headers => $headers });
my $info = decode_json($response->{ content });

print Dumper($info);

print Dumper($info->{ compute }->{ vmId });
