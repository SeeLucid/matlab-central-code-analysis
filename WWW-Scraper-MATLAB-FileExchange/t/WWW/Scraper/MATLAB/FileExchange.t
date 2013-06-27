use Test::Most;

BEGIN { use_ok( 'WWW::Scraper::MATLAB::FileExchange' ); }
require_ok( 'WWW::Scraper::MATLAB::FileExchange' );

my $fe;
ok($fe = WWW::Scraper::MATLAB::FileExchange->new(), 'build instance' );

my $uri_to_id = {
	q,http://www.mathworks.com/matlabcentral/fileexchange/58-routh-m, => 58,
	q,http://www.mathworks.com/matlabcentral/fileexchange/175-htmltool, => 175,
};

my $id_to_uris = {
	58 => [
		q,http://www.mathworks.com/matlabcentral/fileexchange/58, ,
		q,http://www.mathworks.com/matlabcentral/fileexchange/58?download=true, ,
	],
};


###

subtest "Verify get_script_by_id" => sub {
	can_ok 'WWW::Scraper::MATLAB::FileExchange', 'get_script_by_id';
	# TODO
};

my $id_to_uri_test = sub {
	my ($idx, $uri_type) = @_;
	for my $id (keys $id_to_uris) {
		my $uris = $id_to_uris->{$id};
		is( $fe->id_to_desc_uri($id), $uris->[0] , "$uri_type URI ID for script ID $id");
	}
};

subtest "Verify id_to_desc_uri: test of ID to URI mapping" => sub {
	can_ok 'WWW::Scraper::MATLAB::FileExchange', 'id_to_desc_uri';
	$id_to_uri_test->(0, 'description');
};

subtest "Verify id_to_download_uri: test of ID to URI mapping" => sub {
	can_ok 'WWW::Scraper::MATLAB::FileExchange', 'id_to_download_uri';
	$id_to_uri_test->(1, 'download');
};

subtest "Verify uri_to_id: test of URI to ID mapping" => sub {
	can_ok 'WWW::Scraper::MATLAB::FileExchange', 'uri_to_id';
	for my $uri (keys $uri_to_id) {
		my $id = $uri_to_id->{$uri};
		is( $fe->uri_to_id($uri), $id, "URI ID for script ID $id");
	}
};

subtest "Verify get_result_uris_from_search_page: extract URIs" => sub {
	can_ok 'WWW::Scraper::MATLAB::FileExchange', 'get_result_uris_from_search_page';
	use HTML::TreeBuilder;
	my $html_tree = HTML::TreeBuilder->new_from_url('http://www.mathworks.com/matlabcentral/fileexchange/index?page=2&sort=date_asc_submitted&term=');
	my $uris;
	$uris = $fe->get_result_uris_from_search_page($html_tree);
	is( @$uris, 50, 'extracted 50 URIs');
	cmp_deeply( $uris, supersetof(
	    "http://www.mathworks.com/matlabcentral/fileexchange/125-hilbert",
		"http://www.mathworks.com/matlabcentral/fileexchange/169-predictle",
		"http://www.mathworks.com/matlabcentral/fileexchange/317-plotxx-m",
	), 'contains 3 expected URIs');
};


done_testing;
