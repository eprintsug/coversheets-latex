$c->{plugins}{"Coverpage"}{params}{disable} = 0;
$c->{plugins}{"Convert::CoverLatex"}{params}{disable} = 0;

# set coverpages to be on by default (i.e. if coverpage field is left UNSPECIFIED a coverpage will be added)
# set below value to 0 if UNSPECIFIED should not add a coverpage
$c->{coverpage}->{default_on} = 1;

my $coverpage = {};
$c->{coverpage} = $coverpage;

$c->{executables}->{pdflatex} = "/usr/bin/pdflatex";
$c->{executables}->{pdftk} = "/usr/bin/pdftk";
$c->{executables}->{pdfinfo} = [ "/usr/bin/pdfinfo" ];

$coverpage->{content_template} = 'coverpage_latex';

# a hash of fields and values
# custom functions or strings can be used as a hash value to return the result of the function, or the string
# or use undef to just get the eprint field value as specified by the key
$c->{coverpage}->{metadata} = {
    'citation' => sub{
        my( $repo, $eprint ) = @_;
        return $eprint->render_citation;
    },
    'url' => sub{
        my( $repo, $eprint ) = @_;
        return $eprint->url;
    },
    'documents.content' => undef, # "documents.content" cannot be used in the LaTeX citation file so all "." are converted to "_", i.e. "documents_content"
	'creators_name;order=gf' => undef,
    'datestamp;res=month;style=long' => undef,
};
