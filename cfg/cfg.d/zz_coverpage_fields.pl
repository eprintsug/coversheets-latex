push @{$c->{fields}->{document}},
    {
        name => "coverpage",
        type => "boolean",
        input_style => 'radio',
    },
    {
        name => "coverpage_hash",
        type => "id",
        maxlength=>64,
    },
;
