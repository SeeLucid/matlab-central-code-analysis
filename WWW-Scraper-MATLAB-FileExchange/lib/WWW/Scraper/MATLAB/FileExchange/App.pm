package WWW::Scraper::MATLAB::FileExchange::App;

use strict;
use warnings;

use WWW::Scraper::MATLAB::FileExchange;
use YAML::XS qw/LoadFile/;
use Path::Class;
use Try::Tiny;
use Parallel::ForkManager;
use IPC::DirQueue;

use LWP::UserAgent;
use HTML::TreeBuilder;
use File::Slurp qw/write_file/;

use Log::Log4perl qw(:easy);

use Time::HiRes qw(sleep);

use Moo;

use constant MAX_PROC => 10;

has config_file => ( is => 'rw' );

has _config => ( is => 'lazy' );

has _output_directory => ( is => 'lazy' );

has _result_page_directory => ( is => 'lazy' );
has _script_directory => ( is => 'lazy' );

has _queue => ( is => 'lazy' );
has _queue_directory => ( is => 'lazy' );

has _logfile => ( is => 'lazy' );

has _conn => ( is => 'lazy' );

sub _build__logfile {
	my ($self) = @_;
	$self->_output_directory->file('scraper.log');
}

sub _build__output_directory {
	my ($self) = @_;
	my $d = dir($self->_config->{directory});
	if($d->is_relative) {
		my $relative_to = dir(); # current directory
		if($self->config_file) {
			# directory of the config file
			$relative_to = file($self->config_file)->dir;
		}
		$d = $relative_to->subdir($d);
	}
	$d->mkpath;
	$d;
}

sub _build__queue {
	my ($self) = @_;
	$self->get_queue;
}

sub get_queue {
	my ($self) = @_;
	IPC::DirQueue->new({ dir => $self->_queue_directory });
}

sub _build__queue_directory {
	my ($self) = @_;
	my $d = dir($self->_output_directory)->subdir('queue');
	$d->mkpath;
	$d;
}

sub _build__config {
	my ($self) = @_;
	# read the YAML config file
	LoadFile($self->config_file);
}

sub _build__result_page_directory {
	my ($self) = @_;
	my $d = $self->_output_directory->subdir('result_page');
	$d->mkpath;
	$d;
}

sub _build__script_directory {
	my ($self) = @_;
	my $d = $self->_output_directory->subdir('script');
	$d->mkpath;
	$d;
}

sub _directory_for_script_id {
	my ($self, $id) = @_;
	$self->_script_directory->subdir($id);
}

sub _file_for_result_page_num {
	my ($self, $num) = @_;
	$self->_result_page_directory->file($num);
}

sub add_url_to_queue {
	my $self = shift;
	$self->_queue->enqueue_string(@_);
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
		$self->add_url_to_queue($url, { rez => $page });
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
		$pm->start and next;
		my $q = $self->get_queue;
		my $job;
		my $ua = LWP::UserAgent->new( agent => 'sloth/0.001' );
		my $scraper = WWW::Scraper::MATLAB::FileExchange->new;

		# pop off queue
		while( $job = $q->pickup_queued_job ) {
			my $meta = $job->{metadata} // {};
			my $url = $job->get_data;
			my $downloaded = 1; # we assume that this iteration will download
			if( exists $meta->{rez} ) { # retrieve a result page
				my $page_num = $meta->{rez};
				INFO "processing result page number $page_num";
				# have we already processed the page?
				# if so, skip
				my $file = $self->_file_for_result_page_num($page_num)->absolute;
				unless ( -f $file and not -z $file ) {
					try {
						INFO "fetching result page $page_num";
						my $response = $ua->get($url);
					    LOGDIE "unable to download result page $page_num" unless $response->is_success;
						INFO "writing result page to $file";
						my $content = $response->decoded_content;
						INFO "fetching all links from result page $page_num";
						my $tree = HTML::TreeBuilder->new_from_content($content);
						my $links = $scraper->get_result_uris_from_search_page($tree);

						# add each link to queue
						for my $link (@$links) {
							my $script_id = $scraper->uri_to_id($link);
							INFO "inserting script $script_id <$link> into queue";
							$self->add_url_to_queue($link, { id => $script_id });
						}

						# write it out
						write_file($file, $content);
						INFO "wrote result page to $file";
					} catch {
						# add back to queue
						WARN "unable to retrieve result page $page_num, enqueueing again: $_";
						$file->remove;
						$self->add_url_to_queue($url, $meta);
					};
				} else {
					INFO "SKIP: result page $page_num already processed";
					$downloaded = 0;
				}
			} elsif( exists $meta->{id} ) { # retrive a script
				my $script_id = $meta->{id};

				my $dir = $self->_directory_for_script_id($script_id)->absolute;
				# have we already downloaded the script?
				# if so, skip
				unless( -d $dir ) {
					try {
						my $desc_uri = $scraper->id_to_desc_uri($script_id);
						my $down_uri = $scraper->id_to_download_uri($script_id);

						INFO "fetching script $script_id";
						INFO "download script $script_id desc. page";
						my $desc_response = $ua->get($desc_uri);
						INFO "download script $script_id file";
						my $down_response = $ua->get($down_uri);
						
						LOGDIE "unable to download script $script_id: [$desc_response->status_line, $down_response->status_line]"
							unless $desc_response->is_success and $down_response->is_success;
						INFO "writing script $script_id to disk";
						$dir->mkpath;
						# write to disk
						my $desc_filename = $dir->file("$script_id.desc.html");

						my $down_name  = $down_response->filename // "$script_id.download";
						my $clean_name = $down_name =~ s/[\0\/]//gr;
						my $down_filename = $dir->file($down_name);
						write_file($desc_filename, $desc_response->decoded_content);
						write_file($down_filename, {binmode => ':raw'}, $down_response->decoded_content);
						INFO "wrote script $script_id to disk";
					} catch {
						# add back to queue
						WARN "unable to retrieve script $script_id, enqueueing again: $_";
						$dir->rmtree;
						$self->add_url_to_queue($url, $meta);
					};
				} else {
					INFO "SKIP: script $script_id already processed";
					$downloaded = 0;
				}
			}

			# sleeping on the job
			sleep( rand(10) + 5  ) if $downloaded;
		}
		$pm->finish; # do the exit in the child process
	}

	$pm->wait_all_children;
}

sub retrieve_scripts {
	my ($self, $uris) = @_;
}

1;
