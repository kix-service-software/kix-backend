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

use Kernel::API::Validator::UserValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::UserValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# validate valid UserID
# run test for each supported attribute
foreach my $Attribute ( qw(OwnerID ResponsibleID UserID) ) {
    my $Result = $ValidatorObject->Validate(
        Attribute => $Attribute,
        Data      => {
            $Attribute => 1,
        }
    );

    $Self->True(
        $Result->{Success},
        "Validate() - valid UserID - $Attribute",
    );
}

# validate invalid UserID
foreach my $Attribute ( qw(OwnerID ResponsibleID UserID) ) {
    my $Result = $ValidatorObject->Validate(
        Attribute => $Attribute,
        Data      => {
            $Attribute => -9999,
        }
    );

    $Self->False(
        $Result->{Success},
        "Validate() - invalid UserID - $Attribute",
    );
}

# validate valid User
# run test for each supported attribute
foreach my $Attribute ( qw(Owner Responsible) ) {
    my $Result = $ValidatorObject->Validate(
        Attribute => $Attribute,
        Data      => {
            $Attribute => 'admin',
        }
    );

    $Self->True(
        $Result->{Success},
        "Validate() - valid User - $Attribute",
    );
}

# validate invalid User
# run test for each supported attribute
foreach my $Attribute ( qw(Owner Responsible) ) {
    my $Result = $ValidatorObject->Validate(
        Attribute => $Attribute,
        Data      => {
            $Attribute => '____test____',
        }
    );

    $Self->False(
        $Result->{Success},
        "Validate() - invalid User - $Attribute",
    );
}

# validate invalid attribute
my $Result = $ValidatorObject->Validate(
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
