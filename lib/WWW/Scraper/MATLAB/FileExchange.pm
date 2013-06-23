package WWW::Scraper::MATLAB::FileExchange;

use strict;
use warnings;
use Moo;

use WWW::Mechanize;

sub get_script_by_id {
	my ($self, $id) = @_;
	# TODO get script
}

sub uri_to_id {
	my ($self, $uri) = @_;
	my $fe_re = qr,^http://www\.mathworks\.com/matlabcentral/fileexchange/(?<ID>(?<NUMID>\d+)(?<RESTID>.*))$,;
	die "URI $uri does not match MATLAB Central File Exchange"
		unless $uri =~ $fe_re;
	return $+{NUMID};
}

sub id_to_download_uri {
	my ($self, $id) = @_;
	return $self->id_to_desc_uri($id)."?download=true";
}

sub id_to_desc_uri {
	my ($self, $id) = @_;
	return "http://www.mathworks.com/matlabcentral/fileexchange/$id";
}

1;
