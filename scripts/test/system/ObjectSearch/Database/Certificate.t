# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

my $ObjectTypeModule = 'Kernel::System::ObjectSearch::Database::Certificate';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $ObjectTypeModule ) );

# create backend object
my $ObjectTypeObject = $ObjectTypeModule->new(
    %{ $Self },
    ObjectType => 'Certificate'
);
$Self->Is(
    ref( $ObjectTypeObject ),
    $ObjectTypeModule,
    'ObjectType object has correct module ref'
);

# check supported methods
for my $Method ( qw(Init GetBaseDef GetPermissionDef GetSearchDef GetSortDef GetSupportedAttributes) ) {
    $Self->True(
        $ObjectTypeObject->can($Method),
        'ObjectType object can "' . $Method . '"'
    );
}

# check Init
my $InitReturn = $ObjectTypeObject->Init();
$Self->Is(
    $InitReturn,
    1,
    'Init provides expected data'
);

# check GetBaseDef
my $GetBaseDefReturn = $ObjectTypeObject->GetBaseDef();
$Self->IsDeeply(
    $GetBaseDefReturn,
    {
        Select  => ['vfs.id', 'vfs.filename'],
        From    => ['virtual_fs vfs'],
        Where   => ['vfs.filename LIKE \'Certificate/%\''],
        OrderBy => ['vfs.id ASC']
    },
    'GetBaseDef provides expected data'
);

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut