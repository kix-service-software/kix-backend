# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::Job::Reporting;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::Job::Common);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Automation::Job::Reporting - job type for automation lib

=head1 SYNOPSIS

Handles reporting jobs.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

Run this job module. Returns the list of DefinitionIDs to run this job on.

Example:
    my @DefinitionIDs = $Object->Run(
        Data   => {},        # optional, contains the relevant data given by an event or otherwise
        UserID => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # do the search
    my %DefinitionList = $Kernel::OM->Get('Reporting')->ReportDefinitionList(
        Valid => 1,
    );

    my @Definitions;
    DEFINITION:
    foreach my $ID ( sort keys %{DefinitionList} ) {
        my %Definition = $Kernel::OM->Get('Reporting')->ReportDefinitionGet(
            ID => $ID
        );
        next DEFINITION if !%Definition;
        push @Definitions, \%Definition;
    }
    @Definitions = $Kernel::OM->Get('Main')->FilterObjectList(
        Data   => \@Definitions,
        Filter => $Param{Filter},
    );

    my @DefinitionIDs = map { $_->{ID} } @Definitions;

    return @DefinitionIDs;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
