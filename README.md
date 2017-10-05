### You must disable the coversheets plugin (if it is enabled)###
``` ./tools/epm disable repoID coversheets```

1) vim cfg/cfg.d/document_fields.pl
    add this:
```
$c->{fields}->{document} = [
        {
                name => "coverpage",
                type => "boolean",
                input_style => 'radio',
        },
	];
```
    
2) Add the field in the workflow:
```
vi repoid/cfg/workflows/eprint/defaul.xml
```
add this under the **<component type="Documents">:**
```
<field ref="coverpage" />
```
3) Update the DB in order to create a space for the new field

4) cp lib/defaultcfg/cfg.d/document_validate.pl archives/repoID/cfg/cfg.d

5) Add the following snippet in document_validate.pl after the "*my $xml = $repository->xml();*" :
```
	my $cp = $repository->plugin('Coverpage');
        if ($cp) {
          my $cp_switch = $document->get_value('coverpage') || '';
          if ($cp_switch ne 'FALSE') {
            my $conv_plugin = $cp->get_conversion_plugin($document);
            if ($conv_plugin) {
              my @conv_problems = $conv_plugin->validate($document);
              if (@conv_problems) {
                push @problems, @conv_problems;
                $repository->log("coverpage conversion problems, setting coverpage to false");
                $document->set_value('coverpage', 'FALSE');
                $document->commit;
              }
            } else {
            }
          } else {
            $cp->remove_coverpage($document);
            my $fieldname = $repository->make_element( "span", class=>"ep_problem_field:documents" );
            push @problems, $repository->html_phrase('validate:coverpage_disabled',
                                                  fieldname => $fieldname);
          }
    	}
```

6) Make sure the following apps are installed on your system:
  1. /usr/bin/pdflatex (package name: texlive-latex-base on ubuntu).

1. /usr/bin/pdftk (package name: pdftk).

1.  c) /usr/bin/pdfinfo (package name:poppler-utils on ubuntu).