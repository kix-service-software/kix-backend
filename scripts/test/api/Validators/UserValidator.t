# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Debugger;
use Kernel::API::Validator::UserValidator;

my $DebuggerObject = Kernel::API::Debugger->new(
    DebuggerConfig   => {
        DebugThreshold  => 'debug',
        TestMode        => 1,
    },
    WebserviceID      => 1,
    CommunicationType => 'Provider',
    RemoteIP          => 'localhost',
);

# get validator object
my $ValidatorObject = Kernel::API::Validator::UserValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

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
            $Attribute => 'root@localhost',
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

# cleanup is done by RestoreDatabase.

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
