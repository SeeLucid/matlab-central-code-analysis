use Test::More tests => 5;

BEGIN { use_ok( 'WWW::Scraper::MATLAB::FileExchange' ); }
require_ok( 'WWW::Scraper::MATLAB::FileExchange' );

my $fe;
ok($fe = WWW::Scraper::MATLAB::FileExchange->new(), 'build instance' );

my $uri_to_id = {
	q,http://www.mathworks.com/matlabcentral/fileexchange/58-routh-m, => 58,
	q,http://www.mathworks.com/matlabcentral/fileexchange/175-htmltool, => 175,
};

subtest 'Test of URI to ID mapping' => sub {
	for my $uri (keys $uri_to_id) {
		my $id = $uri_to_id->{$uri};
		is( $fe->uri_to_id($uri), $id, "URI ID for script ID $id");
	}
};

my $id_to_uris = {
	58 => [
		q,http://www.mathworks.com/matlabcentral/fileexchange/58, ,
		q,http://www.mathworks.com/matlabcentral/fileexchange/58?download=true, ,
	],
};

subtest 'Test of ID to URI mapping' => sub {
	for my $id (keys $id_to_uris) {
		my $uris = $id_to_uris->{$id};
		is( $fe->id_to_desc_uri($id), $uris->[0] , "description URI ID for script ID $id");
		is( $fe->id_to_download_uri($id), $uris->[1], "download URI for script ID $id");
	}
};

done_testing;
