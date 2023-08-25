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

use Kernel::API::Operation;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# skip SSL certificate verification
$Helper->SSLVerify(
    SkipSSLVerify => 1,
);

# create object with false options
my $OperationObject;

# provide no objects
$OperationObject = Kernel::API::Operation->new();
$Self->IsNot(
    ref $OperationObject,
    'API::Operation',
    'Operation::new() fail check, no arguments',
);

# provide empty operation
$OperationObject = Kernel::API::Operation->new(
    WebserviceID   => 1,
    OperationType  => {},
);
$Self->IsNot(
    ref $OperationObject,
    'API::Operation',
    'Operation::new() fail check, no OperationType',
);

# provide incorrect operation
$OperationObject = Kernel::API::Operation->new(
    WebserviceID   => 1,
    OperationType  => 'Test::ThisIsCertainlyNotBeingUsed',
);
$Self->IsNot(
    ref $OperationObject,
    'API::Operation',
    'Operation::new() fail check, wrong OperationType',
);

# provide no WebserviceID
$OperationObject = Kernel::API::Operation->new(
    OperationType  => 'Test::Test',
);
$Self->IsNot(
    ref $OperationObject,
    'API::Operation',
    'Operation::new() fail check, no WebserviceID',
);

# create object
$OperationObject = Kernel::API::Operation->new(
    WebserviceID   => 1,
    Operation      => 'UserSearch',
    OperationType  => 'V1::User::UserSearch',
    OperationRouteMapping => {},
    ParentMethodOperationMapping => {},
    AvailableMethods => {},
    RequestMethod => 'GET',
    RequestURI    => '/system/users',
    CurrentRoute  => '/system/users'
);
$Self->Is(
    ref $OperationObject,
    'Kernel::API::Operation',
    'Operation::new() success',
);

# run without data
my $ReturnData = $OperationObject->Run();
$Self->Is(
    ref $ReturnData,
    'HASH',
    'OperationObject call response',
);
$Self->True(
    $ReturnData->{Success},
    'OperationObject call no data provided',
);

# run with empty data
$ReturnData = $OperationObject->Run(
    Data => {},
);
$Self->Is(
    ref $ReturnData,
    'HASH',
    'OperationObject call response',
);
$Self->True(
    $ReturnData->{Success},
    'OperationObject call empty data provided',
);

# run with invalid data
$ReturnData = $OperationObject->Run(
    Data => [],
);
$Self->Is(
    ref $ReturnData,
    'HASH',
    'OperationObject call response',
);
$Self->False(
    $ReturnData->{Success},
    'OperationObject call invalid data provided',
);

# run with some data
$ReturnData = $OperationObject->Run(
    Data => {
        'from' => 'to',
    },
);
$Self->True(
    $ReturnData->{Success},
    'OperationObject call data provided',
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
