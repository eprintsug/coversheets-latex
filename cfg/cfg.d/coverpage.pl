$c->{plugins}{"Coverpage"}{params}{disable} = 0;
$c->{plugins}{"Convert::CoverLatex"}{params}{disable} = 0;

my $coverpage = {};
$c->{coverpage} = $coverpage;

$c->{executables}->{pdflatex} = "/usr/bin/pdflatex";
$c->{executables}->{pdftk} = "/usr/bin/pdftk";
$c->{executables}->{pdfinfo} = [ "/usr/bin/pdfinfo" ];

$coverpage->{content_template} = 'coverpage_latex';

$coverpage->{get_metadata} = sub {

	my ($repo, $plugin, $eprint) = @_;

  	my $creators_gf = $plugin->render_with_property($eprint, 'creators_name',
						'render_order' => 'gf');
  	my $datestamp_long = $plugin->render_with_property($eprint, 'datestamp',
						   'render_res'=>'month', 'render_style'=>'long');

	print STDERR "CREATORS: ".$creators_gf."\n";
	print STDERR "DATESTAMP_LONG: ".$datestamp_long."\n";

	  my %data = (
    		'citation' => $plugin->xml2latex($eprint->render_citation()),
    		'url' => $plugin->latex_escape($eprint->url),
    		'content' => '',
    		'creators_givenfirst' => $plugin->xml2latex($creators_gf),
    		'datestamp_long' => $plugin->xml2latex($datestamp_long),
  	);


	print STDERR $data{citation}."\n";
	return %data;

};

$c->add_trigger( EPrints::Const::EP_TRIGGER_DOC_URL_REWRITE, sub {
  # return if !doc-to-cover-page;
  my( %args ) = @_;
  my( $request, $eprint, $doc, $filename, $relations ) =
    @args{qw( request eprint document filename relations )};

  unless ($doc) {
    return undef;
  }
  # don't generate a coverpage for e.g. thumbnails
  if (@$relations) {
    return undef;
  }
  my $repo = $doc->get_session->get_repository;

  my $cp_plugin = $repo->plugin('Coverpage');
  if ($cp_plugin->is_current($doc)) {
    $repo->log("current coverpage for doc ".$doc->get_id." exists");
  } else {
    $repo->log("need to generate coverpage for doc ".$doc->get_id);
  }
  unless ($cp_plugin) {
    $repo->log("Coverpage plugin is missing.");
    return undef;
  }

  my $cpvalue = $doc->get_value('coverpage');
  if (defined $cpvalue && $cpvalue eq 'FALSE') {
    $repo->log("coverpage disabled for doc ".$doc->get_id);
  } else {
    my $cp = $cp_plugin->get_current_coverpage($doc);
    if ($cp) {
      $repo->log("got coverpage for doc ".$doc->get_id." (eprintid: ".
		 ($eprint ? $eprint->get_id : '?').")");
    } else {
      $repo->log("generating coverpage for doc ".$doc->get_id." (eprintid: ".
		 ($eprint ? $eprint->get_id : '?').") failed!");
      $doc->set_value('coverpage', 'FALSE');
      $doc->commit;
      return undef;
    }
    unshift @$relations, "hasCoverPageVersion";
  }
});
