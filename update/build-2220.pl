#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/plugins';
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::Role::Permission;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-2220',
    },
);

use vars qw(%INC);

# update job to unlock tickets with out of office owner
_UpdateUnlockJob();

sub _UpdateUnlockJob {
    my ( $Self, %Param ) = @_;

    my $JobName = 'Owner Out Of Office - unlock ticket';

    my $JobID = $Kernel::OM->Get('Automation')->JobLookup(
        Name => $JobName,
    );

    if ( $JobID ) {
        my %JobData = $Kernel::OM->Get('Automation')->JobGet(
            ID => $JobID,
        );

        my $UpdateNeeded = 0;
        for my $Filter ( @{ $JobData{Filter} } ) {
            next if (
                !IsHashRefWithData( $Filter )
                || !IsArrayRefWithData( $Filter->{AND} )
            );
            my $HasOwnerOutOfOffice = 0;
            my $HasOwnerOutOfOfficeSubstitute = 0;
            for my $FilterElement ( @{ $Filter->{AND} } ) {
                if (
                    $FilterElement->{Field} eq 'OwnerOutOfOffice'
                    && $FilterElement->{Operator} eq 'EQ'
                    && $FilterElement->{Value} eq '1'
                ) {
                    $HasOwnerOutOfOffice = 1;
                }
                if (
                    $FilterElement->{Field} eq 'OwnerOutOfOfficeSubstitute'
                    && $FilterElement->{Operator} eq 'EMPTY'
                    && $FilterElement->{Value} eq '1'
                ) {
                    $HasOwnerOutOfOffice = 1;
                }
            }

            if (
                $HasOwnerOutOfOffice
                && !$HasOwnerOutOfOfficeSubstitute
            ) {
                push(
                    @{ $Filter->{AND} },
                    {
                        "Field"    => "OwnerOutOfOfficeSubstitute",
                        "Value"    => "1",
                        "Operator" => "EMPTY",
                        "Type"     => "NUMERIC"
                    }
                );

                $UpdateNeeded = 1;
            }
        }

        if ( $UpdateNeeded ) {
            my $Success = $Kernel::OM->Get('Automation')->JobUpdate(
                %JobData,
                ID     => $JobID,
                UserID => 1
            );
            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority  => 'error',
                    Message   => 'Could not update filter of job "' . $JobName . '"',
                );

                return;
            }
        }
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority  => 'info',
            Message   => 'Did not found job "' . $JobName . '", nothing to do.',
        );
    }

    return 1;
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
