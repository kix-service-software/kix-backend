# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Validator::ReportDefinitionValidator;

# get ReportDefinition object
my $ReportingObject = $Kernel::OM->Get('Reporting');

# get validator object
my $ValidatorObject = Kernel::API::Validator::ReportDefinitionValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $NameRandom = $Helper->GetRandomID();

# add report definition
my $ReportDefinitionID = $ReportingObject->ReportDefinitionAdd(
    Name       => 'reportdefinition-'.$NameRandom,
    DataSource => 'GenericSQL',
    ValidID    => 1,
    UserID     => 1,
);

$Self->True(
    $ReportDefinitionID,
    'ReportDefinitionAdd() for new report definition',
);

my $ValidData = {
    ReportDefinitionID => $ReportDefinitionID
};

my $InvalidData = {
    ReportDefinitionID => 9999
};

# validate valid ReportDefinitionID
my $Result = $ValidatorObject->Validate(
    Attribute => 'ReportDefinitionID',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid ReportDefinitionID',
);

# validate invalid ReportDefinitionID
$Result = $ValidatorObject->Validate(
    Attribute => 'ReportDefinitionID',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid ReportDefinitionID',
);

# validate invalid attribute
$Result = $ValidatorObject->Validate(
    Attribute => 'InvalidAttribute',
    Data      => {},
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid attribute',
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
