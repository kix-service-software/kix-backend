# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::WebService::Dump;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Webservice',
    'Main',
    'YAML',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Print a web service configuration (in YAML format) into a file.');
    $Self->AddOption(
        Name        => 'name',
        Description => "The name of an existing web service.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'target-path',
        Description => "Specify the output location of the web service YAML configuration file.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $WebServiceList = $Kernel::OM->Get('Webservice')->WebserviceList();
    my %WebServiceListReverse = reverse %{$WebServiceList};

    my $WebServiceName = $Self->GetOption('name');
    $Self->{WebServiceID} = $WebServiceListReverse{$WebServiceName};
    if ( !$Self->{WebServiceID} ) {
        die "A web service with the name $WebServiceName does not exists in this system.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Dumping web service...</yellow>\n");

    my $WebService =
        $Kernel::OM->Get('Webservice')->WebserviceGet(
        ID => $Self->{WebServiceID},
        );

    if ( !$WebService ) {
        my $WebServiceName = $Self->GetOption('name');
        $Self->PrintError("Could not get a web service with the name $WebServiceName from the database!");
        return $Self->ExitCodeError();
    }

    # dump config as string
    my $Config = $Kernel::OM->Get('YAML')->Dump( Data => $WebService->{Config} );

    my $TargetPath = $Self->GetOption('target-path');

    # write configuration in a file
    my $FileLocation = $Kernel::OM->Get('Main')->FileWrite(
        Location => $TargetPath,
        Content  => \$Config,
        Mode     => 'utf8',
    );

    if ( !$FileLocation ) {
        $Self->PrintError("Could not write file $TargetPath!");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
