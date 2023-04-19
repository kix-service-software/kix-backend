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

use vars (qw($Self));

use Kernel::API::Validator::ReportValidator;

# get ReportDefinition object
my $ReportingObject = $Kernel::OM->Get('Reporting');

# get validator object
my $ValidatorObject = Kernel::API::Validator::ReportValidator->new();

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $NameRandom  = $Helper->GetRandomID();

# add report definition
my $ReportDefinitionID = $ReportingObject->ReportDefinitionAdd(
    Name    => 'reportdefinition-'.$NameRandom,
    Type    => 'GenericSQL',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $ReportDefinitionID,
    'ReportDefinitionAdd() for new report definition',
);

# add report
my $ReportID = $ReportingObject->ReportCreate(
    DefinitionID => $ReportDefinitionID,
    Parameters   => {},
    UserID       => 1,
);

$Self->True(
    $ReportID,
    'ReportCreate() for new report',
);

my $ValidData = {
    ReportID => $ReportID
};

my $InvalidData = {
    ReportID => 9999
};

# validate valid ReportDefinitionID
my $Result = $ValidatorObject->Validate(
    Attribute => 'ReportID',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid ReportID',
);

# validate invalid ReportDefinitionID
$Result = $ValidatorObject->Validate(
    Attribute => 'ReportID',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid ReportID',
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

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
