package EPrints::Plugin::Convert::CoverLatex;

#
# $Id: CoverLatex.pm 17483 2011-07-06 13:38:15Z bergolth $
# $URL: https://svn.wu.ac.at/repo/bach/trunk/epub/coverpage-plugin/cfg/plugins/EPrints/Plugin/Convert/CoverLatex.pm $
#

=pod

=head1 NAME

EPrints::Plugin::Convert::CoverLatex - Prepend a latex cover page to a PDF file

=cut

use strict;
use warnings;

use Carp;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

use EPrints::XML;
use HTML::Entities;
use EPrints::TempDir;
our (%FORMATS, @ORDERED, %FORMATS_PREF);
@ORDERED = %FORMATS = qw(
pdf application/pdf
);

# ignore those elements but use their children
my %xml2latex_passthrough = (
  'span' => 1,
  'div' => 1,
  'font' => 1,
  'body' => 1,
  'html' => 1,
);


# formats pref maps mime type to file suffix. Last suffix
# in the list is used.
for(my $i = 0; $i < @ORDERED; $i+=2)
{
    $FORMATS_PREF{$ORDERED[$i+1]} = $ORDERED[$i];
}

our $EXTENSIONS_RE = join '|', keys %FORMATS;

sub new
{
    my( $class, %opts ) = @_;

    my $self = $class->SUPER::new( %opts );

    $self->{name} = "Cover Page";
    $self->{visible} = "all";

    my $template = $self->{session}->get_repository->get_conf( 'coverpage', 'content_template' );
    $self->set_content_template( $template );
    return $self;
}

sub can_convert
{
    my( $plugin, $doc ) = @_;

    # need pdflatex and pdftk
    my $repository = $plugin->get_repository;
    return unless $repository->can_execute( "pdflatex" );
    return unless $repository->can_execute( "pdftk" );

    my %types;

    # Get the main file name
    my $fn = $doc->get_main() or return ();

    if( $fn =~ /\.($EXTENSIONS_RE)$/oi )
    {
        $types{"coverpage"} = { plugin => $plugin, };
    }

    return %types;
}

sub export
{
    my ( $plugin, $target_dir, $doc, $type, $cover_tex ) = @_;

    # need pdflatex and pdftk
    my $repository = $plugin->get_repository;
    return unless $repository->can_execute( "pdflatex" );
    return unless $repository->can_execute( "pdftk" );
    my $noise = $repository->get_noise || 0;

    my $pdflatex = $repository->get_conf( "executables", "pdflatex" );
    my $pdftk = $repository->get_conf( "executables", "pdftk" );

    unless( $cover_tex )
    {
        if( $plugin->{'cover_tex'} )
        {
            $cover_tex = $plugin->{'cover_tex'};
        }
        else
        {
            $cover_tex = $plugin->get_content_source($doc);
        }
    }
    unless( $cover_tex )
    {
          return;
    }

    # temp dir for running pdflatex
    my $latex_dir = EPrints::TempDir->new( "coverpageXXXXX", UNLINK => 1 );
    if( !defined $latex_dir )
    {
        $plugin->log( "Failed to create dir $latex_dir" );
        return;
    }

    # write coverpage content to cover.tex
    my $latex_file = EPrints::Platform::join_path( $latex_dir, "cover.tex" );
    if( !open( LATEX, '>:utf8', $latex_file ) )
    {
        $plugin->log( "Failed to create file $latex_file" );
        return;
    }
    print LATEX $cover_tex;
    close( LATEX );

    my $size = -s $latex_file;
    if( defined $size )
    {
        $plugin->log( "LaTeX source $latex_file: $size bytes." );
    }
    else
    {
        $plugin->log( "LaTeX source $latex_file missing, write failed!" );
        return;
    }

    my $redir_out = ( $noise >= 2 ) ? '1>&2' : '>/dev/null 2>&1';

    # running pdflatex without shell causes spurious problems:
    # Error: /usr/bin/pdflatex (file /usr/share/texmf-var/fonts/map/pdftex/updmap/pdftex.map): fflush() failed
    # attempt to create cover page
    # system( '/usr/bin/strace', '-e', 'trace=file', '-o', "$latex_dir/strace.txt", $pdflatex, "-interaction=nonstopmode", "-output-directory=$latex_dir", $latex_file );
    # system( $pdflatex, "-interaction=nonstopmode", "-output-directory=$latex_dir", $latex_file );
    system( "cd $latex_dir && $pdflatex -interaction=nonstopmode cover.tex </dev/null $redir_out" );
    my $rc = $?;
    $plugin->log( "execute cd $latex_dir && $pdflatex -interaction=nonstopmode cover.tex </dev/null $redir_out; rc=$rc" ) if ($noise);
#    system("cp -r $latex_dir /var/tmp/");
#    if (($rc >> 8) gt 1)
#    {
#       $latex_dir->{UNLINK} = 0;
#       $plugin->log( "pdflatex failed with rc ".($rc >> 8) );
#       return;
#   }

    # check it worked
    my $pdf_file = EPrints::Platform::join_path( $latex_dir, "cover.pdf" );
    # $plugin->log( `ls -l $pdf_file` );
    unless( -s $pdf_file )
    {
        $plugin->log( "Could not generate $pdf_file. Check that coverpage content is valid LaTeX." );
        return;
    }

    unless( -d $target_dir )
    {
        EPrints::Platform::mkdir( $target_dir);
    }

    my $output_file = $doc->get_main;
    my $output_path = EPrints::Platform::join_path( $target_dir, $doc->get_main );
    if( -e $output_path )
    {
        # remove old covered file
        unlink( $output_path );
    }

    # prepend cover page
    system( $pdftk, $pdf_file, $plugin->get_document_file($doc), "cat", "output", $output_path );
    $rc = $?;
    $plugin->log( "executing $pdftk $pdf_file " . $plugin->get_document_file($doc) . " cat output $output_path; rc=$rc" ) if ($noise);

    # check it worked
    if( $rc || (! -e $output_path) )
    {
        $plugin->log("pdftk could not create $output_path (rc: $rc). Check the PDF is not password-protected.");
        return;
    }

    EPrints::Utils::chown_for_eprints( $output_path );

    return ($output_file);
}

sub set_content_template
{
    my( $plugin, $template ) = @_;
    $template ||= 'coverpage';
    $plugin->{'content_template'} = $template;
}

sub get_content_source
{
    my( $plugin, $doc ) = @_;
    my $content_src = $plugin->doc_citation( $doc, $plugin->{'content_template'} );
    unless( $content_src )
    {
        $plugin->log( "Error: Unable to get content!" );
        return;
    }
    return $content_src;
}

sub doc_citation
{
    my( $self, $doc, $cit_name ) = @_;

    my $repo = $self->get_repository;
    my $eprint = $doc->get_eprint();
    my $eprint_ds = $eprint->get_dataset();

    my $cspec = $repo->get_citation_spec( $eprint_ds, $cit_name );

    my $cp_plugin = $repo->plugin( 'Coverpage' );
    unless( $cp_plugin )
    {
        print STDERR "Coverpage plugin is missing.";
        return;
    }

    # get our coverpage data
    my %data = $cp_plugin->get_metadata( $eprint, $doc );

    # transform the data into latex compatible format
    my %latex_data;
    foreach my $key ( keys %data )
    {
        if( ref( $data{$key} ) ne '' ) # we have a bit of xml/dom
        {
            $latex_data{$key} = $self->xml2latex( $data{$key} );
        }
        else # we just have a string
        {
            $latex_data{$key} = $self->latex_escape( $data{$key} );
        }
    }

    my %params = (
        item => $eprint,
        in => 'citation eprint/coverpage',
        session => $repo,
        latex => \%latex_data
    );

    # EPC::process encodes entities in %params
    my $latex = EPrints::XML::EPC::process( $cspec, %params );
    return &_decode_entities_latex( $latex->toString );
}

sub get_document_file
{
    my( $self, $doc ) = @_;

    my( $file ) = $doc->stored_file( $doc->value( "main" ) );
    return if !defined $file;

    return $file->get_local_copy;
}

sub validate
{
    my( $self, $doc ) = @_;
    my @problems = ();
    if( $self->pdf_is_encrypted( $doc ) )
    {
        my $repository = $self->get_repository;
        my $fieldname = $repository->make_element( "span", class => "ep_problem_field:documents" );
        push @problems, $repository->html_phrase( 'coverlatex:validate_encrypted', fieldname => $fieldname );
    }
    return @problems;
}

sub doc_is_supported { ! shift->pdf_is_encrypted(@_) }

sub pdf_is_encrypted
{
    my( $self, $input ) = @_;
    my $info = ( ref( $input ) eq 'HASH' ) ? $input : $self->_pdfinfo( $self->get_document_file( $input ) );
    # $self->log("pdf_is_encrypted: ".$info->{'encrypted'});
    return ( $info->{'encrypted'} =~ /^yes/i );
}

sub _pdfinfo
{
    my( $self, $filename ) = @_;
    my $repository = $self->get_repository;
 
    my $pdfinfo = $repository->get_conf( "executables", "pdfinfo" );
    unless( $pdfinfo )
    {
        return undef;
    }
    unless( ref $pdfinfo )
    {
        $pdfinfo = [ $pdfinfo ];
    }
 
    my $fh;
    open( $fh, '-|', @$pdfinfo, $filename ) or $self->log( "Error: Unable to run @$pdfinfo $filename: $!" );
    my $line;
    my %info = ();
    while( $line = <$fh> )
    {
        if( $line =~ /^([^:]+?)\s*:\s*(.+)/ )
        {
            $info{lc($1)} = $2;
        }
    }
    close $fh;
    if( keys %info )
    {
        return \%info;
    }
    return undef;
}

sub xml2latex
{
    my( $self, $node ) = @_;
    return &_xml2latex( $node );
}

sub _xml2latex
{
    my( $node ) = @_;
    my @parts;
    if( EPrints::XML::is_dom( $node, "Element" ) )
    {
        my $tagname = $node->nodeName;
        $tagname =~ s/^xhtml://;
        my @children = $node->getChildNodes;
        my $class = $node->getAttribute( 'class' );
        if( $xml2latex_passthrough{$tagname} )
        {
            push @parts, map( &_xml2latex($_), @children );
        }
        elsif( $tagname eq 'em' )
        {
            push( @parts, '\emph{', map(&_xml2latex($_), @children), '}' );
        }
        elsif( $tagname eq 'a' )
        {
            # \href{my_url}{description}
            push(@parts, '\href{', $node->getAttribute('href'), '}{', map(&_xml2latex($_), @children), '}' );
        }
        elsif( $tagname eq 'br' )
        {
            # \\
            push( @parts, "\\\\\n" );
        }
        elsif( $tagname eq 'p' )
        {
            push( @parts, "\n\n" );
        }
        else
        {
            # ignore unknown elements and their contents
            # TODO: b, i, blockquote, center, code, ul, ol, li, pre, strike, strong, sub, sup, u
        }
    }
    elsif( EPrints::XML::is_dom( $node, "DocumentFragment" ) )
    {
        push( @parts, map(&_xml2latex($_), $node->getChildNodes) ); 
    }
    elsif( EPrints::XML::is_dom( $node,
        "Text",
        "CDATASection",
        "ProcessingInstruction",
        "EntityReference" 
    ) )
    {
        my $txt = $node->nodeValue();
        utf8::decode($txt) unless utf8::is_utf8( $txt );
        push @parts, &_latex_escape( $txt );
    }
    return join( '', @parts );
}

sub latex_escape
{
    my( $self, $txt ) = @_;
    return &_latex_escape( $txt );
}

# text to latex
sub _latex_escape
{  
    my $s = shift;
    my $escape_amp = shift;
    # print STDERR "LEO: _latex_escape: $s\n";
    # do both at once to avoid \ -> \textbackslash{} -> \textbackslash\{\}
    if( $escape_amp )
    {
        $s =~ s/(\\)|([_\$&%#{}~])/
        defined $1 ? '\textbackslash{}' : "\\$2"
        /ge;
    }
    else
    {
        $s =~ s/(\\)|([_\$%#{}~])/
        defined $1 ? '\textbackslash{}' : "\\$2"
        /ge;
    }
    # strip control-chars
    $s =~ s|[\x00-\x09\x0b-\x1f]||g;
    return $s;
}

sub decode_entities_latex
{
    shift;
    # print STDERR "LEO: decode_entities_latex: $_\n";
    &_decode_entities_latex(@_);
}

# e.g. &amp; -> \&
sub _decode_entities_latex
{
  my @txt = @_;
  my $c;
  for my $t (@txt) {
    # $1 = &999;
    # $2 = 007
    # $3 = 0abc
    # $4 = amp
    $t =~ s/(&(?:\#(?:(\d+)|(?:[xX]([0-9a-fA-F]+)))|(\w+));)/
      # print STDERR "LEO: R: 1: $1, 2: $2, 3: $3, 4: $4\n";
      if (defined($2) || defined($3)) {
	# &#007; || &#xabcd;
	$c = defined($2) ? $2 : hex($3);
	if ($c < 256) {
	  $c = chr($c);
	} else {
	  $c = $1;
	}
      } elsif (defined($4)) {
	# &amp;
	$c = $HTML::Entities::entity2char{$4} || $1;
      }
      # print STDERR "LEO: c: $c\n";
      if ($c eq "\xa0") {
	# may not use return here!
	'~'; # nbsp
      } else {
	# also escape an ampersand here!
	&_latex_escape($c, 1);
      }
    /egx;
  }
  wantarray ? @txt : $txt[0];
}

sub log
{
    my $self = shift;
    $self->{'repository'}->log('['.$self->{'id'}."]: @_");
}

1;
