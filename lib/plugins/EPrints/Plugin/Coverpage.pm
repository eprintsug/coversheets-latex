package EPrints::Plugin::Coverpage;

#
# $Id: Coverpage.pm 16839 2011-04-19 12:32:36Z bergolth $
# $URL: https://svn.wu.ac.at/repo/bach/trunk/epub/coverpage-plugin/cfg/plugins/EPrints/Plugin/Coverpage.pm $
#

use strict;
use warnings;
use Scalar::Util;
use Encode qw( encode_utf8 );
use Digest::MD5 qw(md5_hex);

our @ISA = qw/ EPrints::Plugin /;

sub new
{
    my( $class, %opts ) = @_;
    my $self = $class->SUPER::new( %opts );
    $self->{name} = "Coverpage";
    return $self;
}

sub get_metadata
{
    my( $self, $eprint, $doc ) = @_;

    my $repo = $self->{'repository'};
    my $ds = $eprint->dataset;

    my %coverpage_fields = %{$repo->get_conf( "coverpage", "metadata" )};
    my %data;
    foreach my $key ( keys %coverpage_fields )
    {
        if( ref( $coverpage_fields{$key} ) eq "CODE" ) # we have a custom function defined for this coverpage field
        {
            $data{$key} = &{$coverpage_fields{$key}}( $eprint, $doc );
        }
        elsif( !defined $coverpage_fields{$key} ) # just get the value of the field
        {
            # get the field
            # first does the field exist?
            my @fnames = split /[\.\;]/, $key;
            my $fname = $fnames[0];
            next unless $ds->has_field( $fname );

            # if field exists, get the metafield for the appropriate dataset and with the specified render options
            my $field = EPrints::Utils::field_from_config_string( $ds, $key );

            #make sure we're dealing with the right kind of object
            my $dataobj = $eprint;
            if( $field->dataset->id eq "document" )
            {
                $dataobj = $doc;
            }

            # render the value
            my $value = $field->get_value( $dataobj );
            $data{$key} = $field->render_value( $repo, $value, 0, 0, $dataobj );
        }
        elsif( defined $coverpage_fields{$key} ) # we have a value we can simply pass along as is
        {
            $data{$key} = $coverpage_fields{$key};   
        }
    }

    return %data;
}

# gets any existing coverpage docs for the document based on the documents related docs
sub _get_coverpages
{
    my( $self, $doc ) = @_;
    my @relations = ( EPrints::Utils::make_relation( 'hasCoverPageVersion' ) );
    return @{$doc->get_related_objects( @relations )};
}

# returns the first coverpage we know of (but ideally we shouldn't have more than one!)
sub get_coverpage
{
    my( $self, $doc ) = @_;

    my @cpages = $self->_get_coverpages( $doc );
    if( @cpages == 0 )
    {
        $self->log( "No CP found for doc id " . $doc->get_id() );
    }
    elsif( @cpages > 1 )
    {
        $self->log( "More than one CP found for doc id " . $doc->get_id() );
    }
    return $cpages[0];
};

sub doc_type_supported { shift->get_conversion_plugin( @_ ) }

sub get_conversion_plugin
{
    my( $self, $doc ) = @_;
    my $convert = $self->{'repository'}->plugin('Convert');
    my %handler = $convert->can_convert( $doc, 'coverpage' );
    unless( %handler )
    {
        return undef;
    }
    return $handler{'coverpage'}{'plugin'};
}

sub make_coverpage
{
    my( $self, $doc, %opts ) = @_;
    my $repo = $self->{'repository'};

    my $c_plugin = $self->get_conversion_plugin( $doc );
    unless( $c_plugin )
    {
        $self->log("no convert handler for coverpage (doc name: " . $doc->get_main() . ", type: " . $doc->get_type . ") found!");
        return undef;
    }

    if( exists $opts{'coverpage_template'} )
    {
        $c_plugin->set_content_template( $opts{'coverpage_template'} );
    }

    # use $doc->get_type since a coverpage convert plugin will not change the type
    my $cpdoc = $c_plugin->convert( $doc->get_parent, $doc, $doc->get_type );
    if( $cpdoc )
    {
        $doc->add_object_relations($cpdoc,
            EPrints::Utils::make_relation( "hasCoverPageVersion" ) =>
            EPrints::Utils::make_relation( "isCoverPageVersionOf" ));
        $cpdoc->commit;
    
        my $eprint = $doc->get_parent();
    
        # get a hash of all the relevant data used to create the coverpage so we can check in future if any of it has changed and we might need a new coverpage
        my %data = $self->get_metadata( $eprint, $doc );
        $doc->set_value( 'coverpage_hash', $self->_serialise_and_hash_metadata( \%data ) );
        $doc->commit;
    }
    else
    {
        $self->log( "Unable to convert document!" );
    }
    return $cpdoc;
};

sub remove_coverpage
{
    my( $self, $doc, @cpages ) = @_;

    unless( @cpages ) # we've not been told which coverpages to remove, so lets get all the coverpages
    {
        @cpages = $self->_get_coverpages($doc);
    }
 
    for my $cp ( @cpages )
    {
        $self->log( "Removing CP id ". $cp->get_id() . " from doc id " . $doc->get_id() );
        $doc->remove_object_relations( $cp ); # remove relation from original doc
        $cp->remove(); # and remove the coverpage
    }

    # Check for the isCoverPage relation and remove anything that we might find there! (in case the hasCoverPage has been clobbered already
    my $ds = $doc->dataset;

    my $filters = [
        {
            meta_fields => [ 'relation_type' ],
            value => EPrints::Utils::make_relation( 'isCoverPageVersionOf' ),
        },
        {
            meta_fields => [ 'relation_uri' ],
            value => '/id/document/' . $doc->id,
        },
    ];

    my $cps = $ds->search( filters => $filters );
    $cps->map( sub{
        my( undef, undef, $cp ) = @_;
        $cp->remove();   
    } );
    
    $doc->commit();
}

sub replace_coverpage
{
    my ($self, $doc) = @_;
    $self->remove_coverpage( $doc );
    return $self->make_coverpage( $doc );
}

sub is_current
{
    my( $self, $doc, $cp ) = @_;
    my $repo = $self->{'repository'};

    # get a coverpage
    unless( $cp ) #
    {
        $cp = $self->get_coverpage($doc);
    }
    unless( $cp )
    {
        return 0;
    }
    # get the conversion plugin
    my $c_plugin = $self->get_conversion_plugin($doc);
    unless( $c_plugin )
    {
        $self->log("no convert handler for coverpage (doc name: ". $doc->get_main() . ", type: " . $doc->get_type . ") found!");
        return undef;
    }

    # get the document's coverpage hash value - this is used to determine if the current coverpage is up-to-date
    my $cpage_hash = $doc->get_value( "coverpage_hash" );
    unless( $cpage_hash )
    {
        $self->log( "Unable to get a coverpage data hash for the document!" );
        return undef; # there is no coverpage hash for the doc, so we can assume it is not current
    }

    # generate an up to date coverpage hash to compare with the one stored against the document
    my $eprint = $doc->get_parent();
    my $current_hash = 0;

    if( $eprint )
    {
        # generate a new coverpage data hash to see if anything has changed
        # first get the data we'd use to generate a coverpage
        my %data = $self->get_metadata( $eprint, $doc );
        $current_hash = $self->_serialise_and_hash_metadata( \%data ); 
    }

    # now compare our newly generated hash with the one stored by the document
    if( $current_hash eq $cpage_hash )
    {
        $self->log( "CP is current." );
        return 1;
    }
    else
    {
        $self->log( "CP needs to be updated." );
        return 0;
    }
}

sub _serialise_and_hash_metadata
{
    my( $self, $data ) = @_;

    my $serialised = "";
    foreach my $key ( keys %{$data} )
    {
        if( ref( $data->{$key} ) =~ /^XML::LibXML/ )
        {
            $serialised .= EPrints::Utils::tree_to_utf8( $data->{$key}, undef, undef, undef, 1 );
        }
        else
        {
            $serialised .= $data->{$key};
        }
    }
    return md5_hex( encode_utf8( $serialised ) );
}

sub log
{
    my $self = shift;
    $self->{'repository'}->log('['.$self->{'id'}."]: @_");
}
