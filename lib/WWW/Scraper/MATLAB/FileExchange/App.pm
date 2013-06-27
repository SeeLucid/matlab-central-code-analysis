package WWW::Scraper::MATLAB::FileExchange::App;

use strict;
use warnings;

use WWW::Scraper::MATLAB::FileExchange;
use YAML::XS;
use Path::Class;
use Try::Tiny;
use Parallel::ForkManager;
use IPC::DirQueue;

use Log::Log4perl qw(:easy);

use Moo;

use constant MAX_PROC => 10;

has config_file => ( is => 'rw' );

has _config => ( is => 'lazy' );

has output_directory => ( is => 'lazy' );

has _result_page_directory => ( is => 'lazy' );
has _script_directory => ( is => 'lazy' );

has _queue => ( is => 'lazy' );
has _queue_directory => ( is => 'lazy' );

has _logfile => ( is => 'lazy' );

has _conn => ( is => 'lazy' );

sub _build__logfile {
	my ($self) = @_;
	$self->output_directory->file('scraper.log');
}

sub _build_output_directory {
	my ($self) = @_;
	my $d = dir($self->config->{directory});
	$d->mkpath;
}

sub _build_queue {
	my ($self) = @_;
	IPC::DirQueue->new({ dir => $self->_queue_directory });
}

sub _build__queue_directory {
	my ($self) = @_;
	my $d = dir($self->output_directory)->subdir('queue');
	$d->mkpath;
	$d;
}

sub _build__config {
	my ($self) = @_;
	# read the YAML config file
	LoadFile($self->config_file);
}

sub add_url_to_queue {
	my ($self, $url) = @_;
	$self->_queue->enqueue_string($url);
}

sub run {
	my ($self) = @_;
	Log::Log4perl->easy_init( { level   => $DEBUG,
		file    => ">>" . $self->_logfile } );

	my $start = $self->_config->{first_page};
	my $stop = $self->_config->{last_page};

	my $scraper = WWW::Scraper::MATLAB::FileExchange->new;

	# add all result pages to queue
	for my $page ($start..$stop) {
		my $url = $scraper->url_for_search_page_num($page);
		$self->add_url_to_queue($url);
		INFO "inserting page $page";
	}
	INFO "pages from $start to $stop in queue";

	$self->go_forth();
}

sub go_forth {
	my ($self) = @_;
	my $pm = Parallel::ForkManager->new(MAX_PROC);

	# process queue [in parallel]
	for my $id (0..MAX_PROC-1) {
	}

	$pm->wait_all_children;
}

sub retrieve_scripts {
	my ($self, $uris) = @_;
}

1;
