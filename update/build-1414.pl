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
        LogPrefix => 'framework_update-to-build-1414',
    },
);

use vars qw(%INC);

# update possible values of MobileProcessingState

_UpdateMobileProcessingStateDF();

sub _UpdateMobileProcessingStateDF {
    my ($Self, %Param) = @_;

    $Self->{DynamicFieldObject} = $Kernel::OM->Get('DynamicField');

    my $MobileProcessingDF = $Self->{DynamicFieldObject}->DynamicFieldGet(Name => 'MobileProcessingState');

    if (!$MobileProcessingDF) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not update dynamic field \"MobileProcessingState\"! Dynamic Field not found!"
        );
        return;
    }

    # rename key 'partially executed'
    if (
        IsHashRefWithData($MobileProcessingDF->{Config}) &&
        IsHashRefWithData($MobileProcessingDF->{Config}->{PossibleValues}) &&
        !$MobileProcessingDF->{Config}->{PossibleValues}->{"partially executed"}
    ) {
        $MobileProcessingDF->{Config}->{PossibleValues}->{'partially executed'} = 'partially executed';
        delete $MobileProcessingDF->{Config}->{PossibleValues}->{partiallyexecuted};

        my $Success = $Self->{DynamicFieldObject}->DynamicFieldUpdate(
            %{$MobileProcessingDF},
            UserID          => 1,
        );

        if (!$Success) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not update dynamic field \"$MobileProcessingDF->{Label}\"!"
            );
            return;
        }

        # delete whole cache
        $Kernel::OM->Get('Cache')->CleanUp();
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
