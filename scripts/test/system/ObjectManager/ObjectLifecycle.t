# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use vars (qw($Self));

use Scalar::Util qw/weaken/;

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new();

# test that all configured objects can be created and then destroyed;
# that way we know there are no cyclic references in the constructors

# ToDo: This is a better solution, because this used the EXPORTS files inlcuding the plugins.
# But after first tries there are many problems occured.
# Because in the some core files there are missing dependencies ort objectmanagerdisabled
# my @Objects = keys %{$Kernel::OM->{ObjectMap}};
#
# my %SkipObjects = (
#     'Output::Template::Plugin' => 1,
# );
my @Objects = (
    'Config',
    'Language',
    'Output::HTML::Layout',
    'Auth',
    'Cache',
    'CheckItem',
    'CSV',
    'Contact',
    'Daemon::SchedulerDB',
    'Daemon::DaemonModules::SchedulerTaskWorker',
    'Daemon::DaemonModules::SchedulerTaskWorker::AsynchronousExecutor',
    'Daemon::DaemonModules::SchedulerTaskWorker::Cron',
    'DB',
    'DynamicField',
    'DynamicField::Backend',
    'Email',
    'Encode',
    'Environment',
    'FileTemp',
    'Automation',
    'HTMLUtils',
    'JSON',
    'LinkObject',
    'Lock',
    'Log',
    'Main',
    'Organisation',
    'PDF',
    'PID',
    'Priority',
    'Queue',
    'State',
    'SysConfig',
    'SystemAddress',
    'Ticket',
    'Time',
    'Type',
    'UnitTest',
    'User',
    'Valid',
    'WebRequest',
    'XML',
    'YAML',
);

my %AllObjects;

OBJECTS:
for my $Object (sort @Objects) {

# ToDo: This is a better solution, because this used the EXPORTS files inlcuding the plugins.
# But after first tries there are many problems occured.
# Because in the some core files there are missing dependencies ort objectmanagerdisabled
#    next OBJECTS if $SkipObjects{$Object};
#
#    {
#       my $Package = $Kernel::OM->GetModuleFor($Object);
#        my $FileName = $Package;
#        $FileName =~ s{::}{/}g;
#        $FileName .= '.pm';
#        print STDERR Data::Dumper::Dumper($FileName);
#        eval {
#            require $FileName;
#        };
#        no strict 'refs';
#        print STDERR Data::Dumper::Dumper(${ $Package . '::ObjectManagerDisabled' });
#        next OBJECTS if ${ $Package . '::ObjectManagerDisabled' };
#    }

    my $PackageObject = $Kernel::OM->Get($Object);
    $AllObjects{$Object} = $PackageObject;
    $Self->True(
        $PackageObject,
        "ObjectManager could create $Object",
    );
}

for my $ObjectName ( sort keys %AllObjects ) {
    weaken( $AllObjects{$ObjectName} );
}

$Kernel::OM->ObjectsDiscard();

for my $ObjectName ( sort keys %AllObjects ) {
    $Self->True(
        !defined( $AllObjects{$ObjectName} ),
        "ObjectsDiscard got rid of $ObjectName",
    );
}

my %SomeObjects = (
    'Config' => $Kernel::OM->Get('Config'),
    'DB'     => $Kernel::OM->Get('DB'),
    'Ticket' => $Kernel::OM->Get('Ticket'),
);

for my $ObjectName ( sort keys %SomeObjects ) {
    weaken( $SomeObjects{$ObjectName} );
}

$Kernel::OM->ObjectsDiscard(
    Objects => ['DB'],
);

$Self->True(
    !$SomeObjects{'DB'},
    'ObjectDiscard discarded DB',
);
$Self->True(
    !$SomeObjects{'Ticket'},
    'ObjectDiscard discarded Ticket, because it depends on DB',
);
$Self->True(
    !$SomeObjects{'Config'},
    'ObjectDiscard did not discard Config',
);

# test custom objects
# note that scripts::test::system::ObjectManager::Dummy creates a scripts::test::system::ObjectManager::Dummy2 in its destructor,
# even though it didn't declare a dependency on it.
# The object manager must be robust enough to deal with that.
$Kernel::OM->ObjectParamAdd(
    'scripts::test::system::ObjectManager::Dummy' => {
        Data => 'Test payload',
    },
);

my $Dummy  = $Kernel::OM->Get('scripts::test::system::ObjectManager::Dummy');
my $Dummy2 = $Kernel::OM->Get('scripts::test::system::ObjectManager::Dummy2');

$Self->True( $Dummy,  'Can get Dummy object after registration' );
$Self->True( $Dummy2, 'Can get Dummy2 object after registration' );

$Self->Is(
    $Dummy->Data(),
    'Test payload',
    'Speciailization of late registered object',
);

weaken($Dummy);
weaken($Dummy2);

$Self->True( $Dummy, 'Object still alive' );

$Kernel::OM->ObjectsDiscard();

$Self->True( !$Dummy,  'ObjectsDiscard without arguments deleted Dummy' );
$Self->True( !$Dummy2, 'ObjectsDiscard without arguments deleted Dummy2' );

$Self->True(
    !$Kernel::OM->{Objects}{'scripts::test::system::ObjectManager::Dummy2'},
    'ObjectsDiscard also discarded newly autovivified objects'
);

$Dummy = $Kernel::OM->Get('scripts::test::system::ObjectManager::Dummy');
weaken($Dummy);
$Self->True( $Dummy, 'Object created again' );

$Kernel::OM->ObjectsDiscard(
    Objects => ['scripts::test::system::ObjectManager::Dummy'],
);
$Self->True( !$Dummy, 'ObjectsDiscard with list of objects deleted object' );

my $NonexistingObject = eval { $Kernel::OM->Get('Nonexisting::Package') };
$Self->True(
    $@,
    "Fetching a nonexisting object causes an exception",
);
$Self->False(
    $NonexistingObject,
    "Cannot construct a nonexisting object",
);

eval { $Kernel::OM->Get() };
$Self->True(
    $@,
    "Invalid object name causes an exception",
);

# cleanup cache
$Kernel::OM->Get('Cache')->CleanUp();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
