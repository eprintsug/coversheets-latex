######################################################################
=pod

=head1 coversheet triggers

This file contains the two triggers for the coversheet package. 

The EP_TRIGGER_STATUS_CHANGE trigger attempts to apply a coversheet
to a document when the eprint enters the state archive.
 
The EP_TRIGGER_DOC_URL_REWRITE trigger attempts to apply a coversheet
if required and then modifies the request to return the covered
version of the document.
This trigger will also test for the debug parameter.

=cut
######################################################################

 
# Settings and trigger for the coversheet process

#

# flag to say whether a watermark is required
$c->{add_coversheet} = 1;

$c->add_dataset_trigger( "eprint", EP_TRIGGER_STATUS_CHANGE, sub
{
	my( %args ) = @_;
	print STDERR "Coversheet EP_TRIGGER_STATUS_CHANGE\n";
	my( $eprint, $old_state, $new_state ) = @args{qw( dataobj old_status new_status )};

	return EP_TRIGGER_OK unless defined $eprint;
	return EP_TRIGGER_OK unless defined $new_state && $new_state eq "archive";
	my $repo = $eprint->repository;
	return EP_TRIGGER_OK unless $repo->config( "add_coversheet" );
       	my $plugin = $repo->plugin( "Convert::AddCoversheet" );
	unless( defined $plugin )
       	{
               	EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] Could not load Convert::AddCoversheet plugin\n" );
		return EP_TRIGGER_OK;
       	}

	$repo->call( "cover_eprint_docs" , $repo, $eprint, $plugin );

	return EP_TRIGGER_OK;
}, priority => 100 );

$c->add_trigger( EP_TRIGGER_DOC_URL_REWRITE, sub
{
	my( %args ) = @_;

	my( $request, $doc, $relations, $filename ) = @args{qw( request document relations filename )};
	# UZH CHANGE ZORA-382 2019/02/20/mb Google Bot gets original document
	my $connection = $request->connection();
	my $client_ip = $connection->remote_ip();
	return EP_TRIGGER_OK if ( $client_ip =~ /^66\.249\./ );
	# END UZH CHANGE ZORA-382
	return EP_TRIGGER_OK unless defined $doc;
	my $repo = $doc->repository;

	my $debug = 0;
        my $uri = URI::http->new( $request->unparsed_uri );
        my %request_args = $uri->query_form();

	if ($request_args{debug})
	{
		$debug = 1;
	}

	EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] start add_coversheet[".$repo->config( "add_coversheet" )."]\n" ) if $debug;
	return EP_TRIGGER_OK unless $repo->config( "add_coversheet" );
	return EP_TRIGGER_OK unless defined $doc;

	# check document is a pdf
	my $format = $doc->value( "format" ); # back compatibility
	my $mime_type = $doc->value( "mime_type" );
	return EP_TRIGGER_OK unless( $format eq "application/pdf" || $mime_type eq "application/pdf" || $filename =~ /\.pdf$/i );

	# ignore thumbnails e.g. http://.../8381/1.haspreviewThumbnailVersion/jacqueline-lane.pdf
	foreach my $rel ( @{$relations || []} )
	{
		return EP_TRIGGER_OK if( $rel =~ /^is\w+ThumbnailVersionOf$/ );
	}

	# ignore volatile documents
	return EP_TRIGGER_OK if $doc->has_relation( undef, "isVolatileVersionOf" );
	return EP_TRIGGER_OK if $doc->has_relation( undef, "isCoversheetVersionOf" );

	my $eprint = $doc->get_eprint;

	my $has_original_cover = $eprint->get_value( "has_original_cover" );
	return EP_TRIGGER_OK if $has_original_cover && $has_original_cover eq "TRUE";

	EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] correct type of relation\n" ) if $debug;

	# search for a coversheet that can be applied to this document
	my $coversheet = EPrints::DataObj::Coversheet->search_by_eprint( $repo, $eprint );
	EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] no coversheet found for item \n" ) if $debug && ! $coversheet;
	return EP_TRIGGER_OK unless( defined $coversheet );

	EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] request is for a pdf and there is a coversheet to apply id[".$coversheet->get_id()."]\n" ) if $debug;

	my $regenerate = 1;

	$doc->get_eprint->set_under_construction( 1 );
	# check whether there is an existing covered version and whether it needs to be regenerated
	my $current_cs_id = $doc->get_value( 'coversheetid' ) || -1; # coversheet used to cover document
	# get the existing covered version of the document
	my $coverdoc = $coversheet->get_coversheet_doc( $doc );

	if( $coversheet->get_id == $current_cs_id )
	{
		# compare timestamps
		$regenerate = $coversheet->needs_regeneration( $doc, $coverdoc );
	}

	EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] need to regenerate the cover [".$regenerate."]\n" ) if $debug;
	if( $regenerate || $debug )
#	if( $regenerate )
	{

        	if( defined $coverdoc )
        	{
			EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] remove old cover [".$coverdoc->get_id()."]\n" ) if $debug;
			# remove existing covered version
                	$doc->remove_object_relations( $coverdoc ); # may not be required?
                	$coverdoc->remove();
               		
			EPrints::DataObj::Coversheet->log( $repo, 
			"[AddCoversheet] Removed coversheet time[".EPrints::Time::get_iso_timestamp()."] ".
			"EPrint [".$eprint->get_id."] Document [".$doc->get_id."] Cover [".$current_cs_id."] \n" );
        	}

		# generate new covered version
        	my $plugin = $repo->plugin( "Convert::AddCoversheet" );
		unless( defined $plugin )
        	{
                	EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] Could not load Convert::AddCoversheet plugin\n" );
			$doc->get_eprint->set_under_construction( 0 );
			return EP_TRIGGER_OK;
        	}

		my $pages = $coversheet->get_pages;
		unless ( $pages )
		{
                	EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] no coversheet pages defined [".$pages."]\n" );
			$doc->get_eprint->set_under_construction( 0 );
               		return EP_TRIGGER_OK;
		}
		$plugin->{_pages} = $pages;
		$plugin->{_debug} = $debug;
 	
		my $newcoverdoc = $plugin->convert( $doc->get_eprint, $doc, "application/pdf" );
		unless( defined $newcoverdoc )
        	{
                	EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] Could not create coversheet document\n" );
			$doc->get_eprint->set_under_construction( 0 );
                	return EP_TRIGGER_OK;
        	}

		# add relation to new covered version
		$newcoverdoc->add_relation( $doc, "isCoversheetVersionOf" );
		$newcoverdoc->add_relation( $doc, "isVolatileVersionOf" );

		$newcoverdoc->set_value( "security", $doc->get_value( "security" ) );
		$newcoverdoc->commit;
	
		# record which coversheet was used
		$doc->set_value( 'coversheetid', $coversheet->get_id );
		$doc->commit;
	
		$coverdoc = $newcoverdoc;

               	EPrints::DataObj::Coversheet->log( $repo, 
			"[AddCoversheet] Applied coversheet time[".EPrints::Time::get_iso_timestamp()."] ".
			"EPrint [".$eprint->get_id."] Document [".$doc->get_id."] Cover [".$coversheet->get_id."] \n" );
	}

	if( defined $coverdoc )
	{
		EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] got covered version doc id[".$coverdoc->get_id."] \n" ) if $debug;
		# return the covered version
		$coverdoc->set_value( "security", $doc->get_value( "security" ) );
		$request->pnotes( filename => $coverdoc->get_main );
		$request->pnotes( document => $coverdoc );
		$request->pnotes( dataobj => $coverdoc );
	}

	# return the uncovered document
	EPrints::DataObj::Coversheet->log( $repo, "[AddCoversheet] finished \n" ) if $debug;

	$doc->get_eprint->set_under_construction( 0 );
	return EP_TRIGGER_DONE;

}, priority => 100 );


