package WWW::Scraper::MATLAB::FileExchange::App;

use strict;
use warnings;

use WWW::Scraper::MATLAB::FileExchange;
use YAML::XS;

use Moo;

has config_file => ( is => 'rw' );

has _config => ( is => 'lazy' );

has output_directory => ( is => 'lazy' );

sub _build_output_directory {
	my ($self) = @_;
	dir($self->config->{directory});
}

sub _build__config {
	my ($self) = @_;
	# read the YAML config file
	LoadFile($self->config_file);
}


1;
