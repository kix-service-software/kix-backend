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

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-2250',
    },
);

use vars qw(%INC);

_UpdateJobFilters();

exit 0;

sub _UpdateJobFilters {
    my ( $Self, %Param ) = @_;

    my @JobNames = (
        'Customer Response - reopen from pending'
    );

    for my $JobName ( @JobNames ) {
        my $JobID = $Kernel::OM->Get('Automation')->JobLookup(
            Name => $JobName,
        );

        if ( $JobID ) {
            my %Job = $Kernel::OM->Get('Automation')->JobGet(
                ID => $JobID
            );

            if ( IsArrayRefWithData( $Job{Filter} ) ) {
                my $Update = 0;

                for my $ORHash ( @{ $Job{Filter} } ) {
                    for my $Operator ( sort keys %{ $ORHash } ) {
                        FILTER:
                        for my $Filter ( @{ $ORHash->{$Operator} } ) {
                            next FILTER if $Filter->{Field} !~ /(?:SenderTypeID|TypeID|ChannelID|DynamicField_PwResetState)/sm;
                            next FILTER if $Filter->{Operator} ne 'EQ';

                            $Filter->{Operator} = 'IN';
                            $Filter->{Value} = [ $Filter->{Value} ];
                            $Update = 1;
                        }
                    }
                }

                if ( $Update ) {
                    $Kernel::OM->Get('Automation')->JobUpdate(
                        %Job,
                        UserID => 1
                    );
                }
            }

        } else {
            $Kernel::OM->Get('Log')->Log(
                Priority  => 'info',
                Message   => 'Did not found job "' . $JobName . '", nothing to do.',
            );
        }
    }
    return 1;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
