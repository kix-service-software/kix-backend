# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::WebService::Delete;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::API::Webservice',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete an existing web service.');
    $Self->AddOption(
        Name        => 'name',
        Description => "The name of an existing web service.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $WebServiceList = $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceList();
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

    $Self->Print("<yellow>Deleting web service...</yellow>\n");

    my $WebService =
        $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceGet(
        ID => $Self->{WebServiceID},
        );

    if ( !$WebService ) {
        my $WebServiceName = $Self->GetOption('name');
        $Self->PrintError("Could not get a web service with the name $WebServiceName from the database!");
        return $Self->ExitCodeError();
    }

    # web service delete
    my $Success = $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceDelete(
        ID     => $WebService->{ID},
        UserID => 1,
    );
    if ( !$Success ) {
        $Self->PrintError('Could not delete web service!');
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
