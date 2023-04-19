# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars qw($Self);

use Data::Dumper;
use Kernel::System::Encode;
use Kernel::System::GeneralCatalog;
use Kernel::System::ImportExport;
use Kernel::System::ImportExport::ObjectBackend::Organisation;
use Kernel::System::Organisation;
use Kernel::System::XML;

$Self->{OrganisationObject}   = Kernel::System::Organisation->new( %{$Self} );
$Self->{EncodeObject}            = Kernel::System::Encode->new( %{$Self} );
$Self->{GeneralCatalogObject}    = Kernel::System::GeneralCatalog->new( %{$Self} );
$Self->{ImportExportObject}      = Kernel::System::ImportExport->new( %{$Self} );
$Self->{ObjectBackendObject}     = Kernel::System::ImportExport::ObjectBackend::Organisation->new( %{$Self} );


# ------------------------------------------------------------ #
# make preparations
# ------------------------------------------------------------ #

# add some test templates for later checks
my @TemplateIDs;
for ( 1 .. 30 ) {

    # add a test template for later checks
    my $TemplateID = $Self->{ImportExportObject}->TemplateAdd(
        Object  => 'Organisation',
        Format  => 'UnitTest' . int rand 1_000_000,
        Name    => 'UnitTest' . int rand 1_000_000,
        ValidID => 1,
        UserID  => 1,
    );

    push @TemplateIDs, $TemplateID;
}

my $TestCount = 1;


# ------------------------------------------------------------ #
# ObjectList test 1 (check CSV item)
# ------------------------------------------------------------ #

# get object list
my $ObjectList1 = $Self->{ImportExportObject}->ObjectList();

# check object list
$Self->True(
    $ObjectList1 && ref $ObjectList1 eq 'HASH' && $ObjectList1->{Organisation},
    "Test $TestCount: ObjectList() - Organisation exists",
);

$TestCount++;


# ------------------------------------------------------------ #
# ObjectAttributesGet test 1 (check attribute hash)
# ------------------------------------------------------------ #

#
#
# TO DO
#
#





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
