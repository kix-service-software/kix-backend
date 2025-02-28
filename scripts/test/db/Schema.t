# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use XML::Simple;

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# check schema - each table must have a primary or at least an unique constraint (needed for Percona clusters)

my $XMLFile = $Kernel::OM->Get('Config')->Get('Home').'/scripts/database/kix-schema.xml';

$Self->True(
    (-f $XMLFile),
    'Schema file exists',
);

my $Content = $Kernel::OM->Get('Main')->FileRead(
    Location => $XMLFile,
);

$Self->True(
    ref $Content eq 'SCALAR',
    'Schema file can be read',
);

$Content = ${$Content};

my $XMLObject = XML::Simple->new( KeepRoot => 0 );

$Self->True(
    $XMLObject,
    'XMLObject is created',
);

my $XMLRef = $XMLObject->XMLin($Content, ForceArray => [ 'Table', 'Index', 'Column', 'ForeignKey', 'Reference' ]);

$Self->True(
    IsHashRefWithData($XMLRef),
    'XML schema content can be parsed',
);

$Self->True(
    IsArrayRefWithData($XMLRef->{Table}),
    'XML schema contains table definitions',
);

foreach my $Table ( @{$XMLRef->{Table}} ) {
    # check if the table has columns
    $Self->True(
        $Table->{Column} && IsArrayRefWithData($Table->{Column}),
        'Table "'.$Table->{Name}.'" has columns',
    );

    # check for unique constraint
    my $HasUnique = IsHashRefWithData($Table->{Unique});

    # check for primary key
    my $HasPrimaryKey = scalar( grep {defined $_ } map { ($_->{PrimaryKey} && $_->{PrimaryKey} eq 'true') ? $_ : undef } @{$Table->{Column}} );

    $Self->True(
        $HasPrimaryKey || $HasUnique,
        'Table "'.$Table->{Name}.'" has a primary key or unique contraint',
    );

    # # check if the table has index definitions for foreign keys
    # if ( IsArrayRefWithData($Table->{ForeignKey}) ) {
    #     foreach my $ForeignKey ( @{$Table->{ForeignKey}} ) {
    #         use Data::Dumper;
    #         print STDERR Dumper($ForeignKey);

    #         # my @Indexes = @{$Table->{Index} || []};
    #         # my $IndexCount = scalar( grep {defined $_ } map { ($_->{} && $_->{PrimaryKey} eq 'true') ? $_ : undef } @Indexes );
    #         # $Self->True(
    #         #     $Table->{Index} && IsArrayRefWithData($Table->{Index}),
    #         #     'Table "'.$Table->{Name}.'" has foreign key on column "'.$ForeignKey->{Local}.'" and an corresponding index',
    #         # );
    #     }
    # }

    # check if the table has a lot of index definitions in relation to the colum count
    if ( IsArrayRefWithData($Table->{Index}) && IsArrayRefWithData($Table->{Column}) ) {
        my $ColumnCount = scalar @{$Table->{Column}};
        my $IndexCount = scalar @{$Table->{Index}};
        $Self->True(
            $IndexCount <= $ColumnCount,
            'Table "'.$Table->{Name}.'" has less indexes ('.$IndexCount.') in relation to columns ('.$ColumnCount.')',
        );
    }
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
