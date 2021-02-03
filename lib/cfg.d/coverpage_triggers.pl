$c->add_trigger( EPrints::Const::EP_TRIGGER_DOC_URL_REWRITE, sub {
    
    # return if !doc-to-cover-page;
    my( %args ) = @_;
    my( $request, $eprint, $doc, $filename, $relations ) = @args{qw( request eprint document filename relations )};
    unless( $doc )
    {
        return undef;
    }
    
    # don't generate a coverpage for e.g. thumbnails
    if( @$relations )
    {
        return undef;
    }
  
    my $repo = $doc->get_session->get_repository;
    my $noise = $repo->get_conf( "coverpage","debug" );

    # do we have a coverpage plugin we can do coverpage stuff with (i.e. checking, adding, removing coverpages)
    my $cp_plugin = $repo->plugin( 'Coverpage' );
    unless( $cp_plugin )
    {
        $repo->log( "Coverpage plugin is missing." ) if( $noise );
        return undef;
    } 

    # don't generate a coverpage if this doc doesn't want one
    my $cpvalue = $doc->get_value( 'coverpage' ); # value set by user in the upload form
    
    my $coverpage_default_on = $repo->get_conf( "coverpage", "default_on" );
    if( $coverpage_default_on ) # coverpages on by default, only disable if explicity set to FALSE
    {
        if( defined $cpvalue && $cpvalue eq 'FALSE' )
        {
            $repo->log( "coverpage disabled for doc " . $doc->get_id ) if( $noise );

            # remove any coverpages we might have generated previously
            $cp_plugin->remove_coverpage( $doc );
            return undef;
        }
    }
    else # coverpages off by default, disable if not set or set to FALSE
    {
        if( !defined $cpvalue || $cpvalue eq 'FALSE' )
        {
            $repo->log( "coverpage disabled for doc " . $doc->get_id ) if( $noise );

            # remove any coverpages we might have generated previously
            $cp_plugin->remove_coverpage( $doc );
            return undef;
        }
    }

    # do we have a current, up-to-date coverpage?
    if( $cp_plugin->is_current( $doc ) )
    {
        $repo->log( "current coverpage for doc " . $doc->get_id . " exists" ) if( $noise );
        unshift @$relations, "hasCoverPageVersion";
    } 
    else # we need a brand new coverpage
    {
        $repo->log( "need to generate coverpage for doc " . $doc->get_id ) if( $noise );
  
        # remove existing coverpages (if there are any) and make a new one      
        my $cp = $cp_plugin->replace_coverpage( $doc );
  
        if( $cp ) # success!
        {
            $repo->log( "got coverpage for doc " . $doc->get_id . " (eprintid: " .
            ( $eprint ? $eprint->get_id : '?' ) . ")" ) if( $noise );
        }
        else # fail
        {
            $repo->log( "generating coverpage for doc " . $doc->get_id . " (eprintid: " .
            ( $eprint ? $eprint->get_id : '?' ) . ") failed!" ) if( $noise );
            return undef;
        }
        unshift @$relations, "hasCoverPageVersion";
    }
});
