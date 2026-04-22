# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $CommonObjectTypeModule = 'Kernel::System::ObjectSearch::Database::CommonObjectType';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $CommonObjectTypeModule ) );

# create backend object
my $CommonObjectTypeObject = $CommonObjectTypeModule->new(
    %{ $Self },
    ObjectType => 'UnitTest'
);
$Self->Is(
    ref( $CommonObjectTypeObject ),
    $CommonObjectTypeModule,
    'CommonObjectType object has correct module ref'
);

# check supported methods
for my $Method (
    qw(
        Init GetBaseDef
        GetSelectDef GetPermissionDef
        GetSearchDef GetFulltextDef GetSortDef
        GetSupportedAttributes
    )
) {
    $Self->True(
        $CommonObjectTypeObject->can($Method),
        'CommonObjectType object can "' . $Method . '"'
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
