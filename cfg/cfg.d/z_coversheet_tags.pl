
# Example definition of tags that can be used in the coversheets
# when using potential utf-8 strings, use the encode() method on the string:
$c->{coversheet}->{tags} = {

		'title' 	=>  sub { 
			my ($eprint) = @_; 
			
			my $title = EPrints::Utils::tree_to_utf8( $eprint->render_value('title'));
			$title =~ s/%/\\%/g;
			return Encode::encode( "UTF-8", $title); 
		},
		
		'type' 		=>  sub { 
			my ($eprint) = @_; 
			return Encode::encode( "UTF-8", EPrints::Utils::tree_to_utf8($eprint->render_value('type'))); 
		},

		'abstract' 	=>  sub { 
			my ($eprint) = @_;

			if ( $eprint->is_set( "abstract" ) )
			{
				my $abstract = EPrints::Utils::tree_to_utf8($eprint->render_value('abstract'));
				$abstract =~ s/%/\\%/g;
				$abstract = "Abstract: " . $abstract;
				return Encode::encode( "UTF-8", $abstract);
			}
			else
			{
				return '';
			}
		},

		'url' 		=>  sub { 
			my ($eprint) = @_;
			return $eprint->get_url;
		},

		'date'		=> sub {
			my( $eprint ) = @_;
			if( $eprint->is_set( "date" ) )
			{
				my $date = $eprint->get_value( "date" );
				$date =~ /^([0-9]{4})/;
				return $1 if defined $1;
			}
			return '';
		},

		'citation'      =>  sub { 
			my ($eprint) = @_; 

			my $cit_str = EPrints::Utils::tree_to_utf8($eprint->render_citation,undef,undef,undef,1 );
			$cit_str =~ s/%/\\%/g;
			return Encode::encode( "UTF-8",$cit_str ); 
		},

		'creators'      =>  sub { 
			my ($eprint) = @_; 

			my $field = $eprint->dataset->field("creators_name");
			if ($eprint->is_set( "creators_name" ) ) 
			{
				return  Encode::encode( "UTF-8", EPrints::Utils::tree_to_utf8($field->render_value($eprint->repository, $eprint->get_value("creators_name"), 0, 1) ) ); 
			}
                        elsif ($eprint->is_set( "editors_name" ) )
                        {
                                 $field = $eprint->dataset->field("editors_name");
                                 return "Edited by: " . Encode::encode( "UTF-8", EPrints::Utils::tree_to_utf8($field->render_value($eprint->repository,$eprint->get_value("editors_name"), 0, 1) ) );
                        }
			else
			{
				return '';
			}
		},

		'doiurl'	=>  sub {
			my ($eprint) = @_; 
			if ($eprint->is_set( "doi" ) )
			{
				my $value = $eprint->get_value( "doi" );
				my $display_value;

				$value =~ s|^http(s)?://doi\.org||;
				
				if( $value !~ /^(doi:)?10\.\d\d\d\d\// )
				{
					($display_value = $value) =~ s/_/\\_/g;
					return "DOI: $display_value";
				}
				else
				{
					$value =~ s/^doi://;
					($display_value = $value) =~ s/_/\\_/g;
					$display_value = "https://doi.org/" . $display_value;
					return "DOI: \\href{https://doi.org/$value}{$display_value}";
				}
			}
			else
			{
				return '';
			}
		},

		'zoraurl'	=> sub {
			my ($eprint) = @_;

			my $zora_url;
			my $douzhdoi = 0;
			my $eprintid = $eprint->get_value("eprintid");

			my @documents = $eprint->get_all_documents();
			foreach my $tmpdoc (@documents)
			{
				my $tmpfile = $tmpdoc->get_value("main");
				$douzhdoi = 1 if ($tmpfile =~ m/\.(?:doc|pdf)$/);
			}

			if ($douzhdoi == 1)
			{
				$zora_url="https://doi.org/10.5167/uzh-" . $eprintid;
			}
			else
			{
				$zora_url="http://www.zora.uzh.ch/" . $eprintid;
			}
			return "\\href{$zora_url}{$zora_url}";
		},

		'doccontent'	=> sub {
			my ($eprint, $doc) = @_;
			my $doccontent = '';

			if ($doc->is_set( "content" ))
			{
				$doccontent = EPrints::Utils::tree_to_utf8( $doc->render_value( 'content' ) );
			}
			return Encode::encode( "UTF-8", $doccontent );
		},

		'license'	=> sub {
			my ($eprint, $doc) = @_;

			my $repo = $eprint->repository;
			my $license_image = '';
			my $license_url = '';
			my $license_image_path = '';
			
			if ($doc->is_set( "license" ) && $doc->is_public )
			{
				my $license_id = $doc->get_value( "license" );
				my $license_phrase = $repo->html_phrase( 'license_image_' . $license_id );
				foreach my $node ( $license_phrase->XML::LibXML::Node::getChildNodes() )
				{
					my $name = $node->nodeName();
					if ($name eq 'a')
					{
						$license_url = $node->getAttribute( "href" );
						foreach my $img_node ($node->XML::LibXML::Node::getChildNodes())
						{
							$name = $img_node->nodeName(); 
							if ($name eq 'img')
							{
								$license_image_path = $img_node->getAttribute( "src" );
							}
						}
					}
				}
				$license_image_path =~ s/\/license\_images\///x;
				$license_image_path =~ /^(.*?)(\.png|\.gif|\.jpg)/;
				$license_image = '\\href{' . $license_url . '}{\XeTeXLinkBox{\includegraphics[width=30mm]{{' . $1 . '}' . $2 . '}}}';
			}

			return $license_image;
		},
};

1;
