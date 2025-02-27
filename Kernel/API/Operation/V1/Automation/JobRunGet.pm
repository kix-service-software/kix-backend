# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Automation::JobRunGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::JobRunGet - API JobRun Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'JobID' => {
            Required => 1
        },
        'RunID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }
    }
}

=item Run()

perform JobRunGet Operation. This function is able to return
one or more job entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            JobID => 123,
            RunID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            JobRun => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @JobRunList;

    my %States = $Kernel::OM->Get('Kernel::System::Automation')->JobRunStateList();

    # start loop
    foreach my $RunID ( @{$Param{Data}->{RunID}} ) {

        # get the Run data
        my %RunData = $Kernel::OM->Get('Kernel::System::Automation')->JobRunGet(
            ID => $RunID,
        );

        if ( !%RunData ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        if ( $RunData{JobID} != $Param{Data}->{JobID} ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        if (%States) {
            $RunData{State} = $States{ $RunData{StateID} } ? $States{ $RunData{StateID} }{Name} : '';
        }

        # add
        push(@JobRunList, \%RunData);
    }

    if ( scalar(@JobRunList) == 1 ) {
        return $Self->_Success(
            JobRun => $JobRunList[0],
        );
    }

    # return result
    return $Self->_Success(
        JobRun => \@JobRunList,
    );
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
