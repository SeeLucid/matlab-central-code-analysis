# ABSTRACT: download scripts from MATLAB FileExchange
package WWW::Scraper::MATLAB::FileExchange;

use strict;
use warnings;
use Moo;

use HTML::TreeBuilder;

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

sub url_for_search_page_num {
	my ($self, $num) = @_;
	return "http://www.mathworks.com/matlabcentral/fileexchange/index?page=$num&sort=date_asc_submitted&term=";
}

sub get_result_uris_from_search_page {
	my ($self, $tree) = @_;
	my @res_elems = $tree->find_by_attribute('class', 'results_title');
	[ map { $_->attr('href') } @res_elems ];
}

1;
