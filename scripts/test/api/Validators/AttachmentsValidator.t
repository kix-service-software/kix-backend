# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Validator::AttachmentsValidator;
use Kernel::System::VariableCheck qw(:all);

# get validator object
my $ValidatorObject = Kernel::API::Validator::AttachmentsValidator->new();

my $ValidData = {
    Attachments => {
        ContentType => 'some content type',
        Filename    => 'some fine name',
    }
};

my %InvalidData = (
    '#01 no array ref' => {
        Attachments => 'NewTicket123-test'
    },
    '#02 no hash ref items' => {
        Attachments => [
            'NewTicket123-test'
        ]
    },
    '#03 missing attribute' => {
        Attachments => [
            {
                ContentType => 'come content type',
            }
        ]
    },
);

# validate valid Attachments
my $Result = $ValidatorObject->Validate(
    Attribute => 'Attachments',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid Attachments',
);

# validate invalid Attachments
foreach my $TestID ( sort keys %InvalidData ) {
    # run test for each supported attribute
    $Result = $ValidatorObject->Validate(
        Attribute => 'Attachments',
        Data      => $InvalidData{$TestID},
    );

    $Self->False(
        $Result->{Success},
        "Validate() - $TestID",
    );
}

# validate invalid attribute
$Result = $ValidatorObject->Validate(
    Attribute => 'InvalidAttribute',
    Data      => {},
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid attribute',
);

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
