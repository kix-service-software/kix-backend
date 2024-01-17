#!/usr/bin/perl
# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1465',
    },
);

use vars qw(%INC);

_UpdateDynamicFields();
_MigrateDynamicFieldData();

# delete whole cache
$Kernel::OM->Get('Cache')->CleanUp();

exit 0;

sub _UpdateDynamicFields {
    my ( $Self, %Param ) = @_;

    # update some dynamic fields
    my %DynamicFieldsToUpdate = (
        'RiskAssumptionRemark' => {
            InternalField => 0,
        },
        'MobileProcessingChecklist010' => {
            InternalField => 0,
        },
        'MobileProcessingChecklist020' => {
            InternalField => 0,
        },
        'Type' => {
            Config => {
                CountMin => 1,
                CountMax => 2,
                CountDefault => 1,
                DefaultValue => undef,
                PossibleNone => 1,
                PossibleValues => {
                    'customer' => 'customer',
                    'supplier/partner (external)' => 'supplier/partner (external)',
                    'supplier/partner (internal)' => 'supplier/partner (internal)',
                    'service provider' => 'service provider'
                },
                TranslatableValues => 1
            }
        }
    );

    my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
    my $DBObject = $Kernel::OM->Get('DB');

    # get all current dynamic fields
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid => 0,
    );
    my %DynamicFieldHash = map { $_->{Name} => $_ } @{$DynamicFieldList};

    # update dynamic fields
    DYNAMICFIELD:
    foreach my $Name (sort keys %DynamicFieldsToUpdate) {

        if ( !$DynamicFieldHash{$Name} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to find Dynamic Field '$Name'!"
            );
            next DYNAMICFIELD;
        }

        if ( exists $DynamicFieldsToUpdate{$Name}->{InternalField} ) {
            # we have to update the internal flag via SQL, because it's not part of DynamicFieldUpdate and shouldn't be
            if ( !$DBObject->Do(
                SQL => 'UPDATE dynamic_field SET internal_field = ?, change_time = current_timestamp, change_by = 1 WHERE id = ?',
                Bind => [
                    \$DynamicFieldsToUpdate{$Name}->{InternalField}, \$DynamicFieldHash{$Name}->{ID},
                ],
            )) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to update internal flag of Dynamic Field '$Name'!"
                );
                next DYNAMICFIELD;
            }
        }

        # update the rest of the DF
        my $Success = $DynamicFieldObject->DynamicFieldUpdate(
            %{ $DynamicFieldHash{$Name} },
            %{ $DynamicFieldsToUpdate{$Name} },
            UserID => 1,
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to update Dynamic Field '$Name'!"
            );
            next DYNAMICFIELD;
        }

        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  => "Updated Dynamic Field '$Name'."
        );
    }

    return 1;
}

sub _MigrateDynamicFieldData {
    my ( $Self, %Param ) = @_;

    my $DBObject = $Kernel::OM->Get('DB');

    # get all current dynamic fields
    my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldList(
        Valid      => 0,
        ResultType => 'HASH'
    );
    $DynamicFieldList = { reverse %{$DynamicFieldList || {}} };

    if ( !$DynamicFieldList->{Type} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to find Dynamic Field 'Type'!"
        );
        return;
    }

    my %KeyMapping = (
       'external supplier' => 'supplier/partner (external)',
       'internal supplier' => 'supplier/partner (internal)'
    );

    # migrate data
    foreach my $Key ( keys %KeyMapping ) {
        my $Success = $DBObject->Do(
            SQL => "UPDATE dynamic_field_value SET value_text = '$KeyMapping{$Key}' WHERE field_id = $DynamicFieldList->{Type} AND value_text = '$Key'"
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to update values for Dynamic Field 'Type' and key '$Key'!"
            );
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Updated values for Dynamic Field 'Type' and key '$Key'."
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
