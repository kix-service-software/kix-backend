# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::WebService::Update;

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

    $Self->Description('Update an existing web service.');
    $Self->AddOption(
        Name        => 'name',
        Description => "The name of an existing web service.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'source-path',
        Description => "Specify the location of the web service YAML configuration file",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $SourcePath = $Self->GetOption('source-path');
    if ( !-r $SourcePath ) {
        die "Source file $SourcePath does not exist / is not readable.\n";
    }

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

    $Self->Print("<yellow>Updating web service...</yellow>\n");

    # read config
    my $Content = $Kernel::OM->Get('Main')->FileRead(
        Location => $Self->GetOption('source-path'),
    );
    if ( !$Content ) {
        $Self->PrintError('Could not read YAML source.');
        return $Self->ExitCodeError();
    }

    my $Config = $Kernel::OM->Get('YAML')->Load( Data => ${$Content} );

    if ( !$Config ) {
        $Self->PrintError('Could not parse YAML source.');
        return $Self->ExitCodeError();
    }

    my $WebService =
        $Kernel::OM->Get('Webservice')->WebserviceGet(
        ID => $Self->{WebServiceID},
        );

    if ( !$WebService ) {
        my $WebServiceName = $Self->GetOption('name');
        $Self->PrintError("Could not get a web service with the name $WebServiceName from the database!");
        return $Self->ExitCodeError();
    }

    # update web service
    my $Success = $Kernel::OM->Get('Webservice')->WebserviceUpdate(
        ID      => $WebService->{ID},
        Name    => $WebService->{Name},
        Config  => $Config,
        ValidID => 1,
        UserID  => 1,
    );
    if ( !$Success ) {
        $Self->PrintError('Could not update web service!');
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
