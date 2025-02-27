# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Automation::JobGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::JobGet - API Job Get Operation backend

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
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }
    }
}

=item Run()

perform JobGet Operation. This function is able to return
one or more job entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            JobID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            Job => [
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

    my @JobList;

    # start loop
    foreach my $JobID ( @{$Param{Data}->{JobID}} ) {

        # get the Job data
        my %JobData = $Kernel::OM->Get('Automation')->JobGet(
            ID => $JobID,
        );

        if ( !%JobData ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # get execution plans if included
        if ( $Param{Data}->{include}->{ExecPlans} ) {
            my $ExecPlans = $Self->_GetExecPlans( JobID => $JobID);
            $JobData{ExecPlans} = $ExecPlans;
        }

        # get macros with action if included
        if ( $Param{Data}->{include}->{Macros} ) {
            my $Macros = $Self->_GetMacros( JobID => $JobID);
            $JobData{Macros} = $Macros;
        }

        # add
        push(@JobList, \%JobData);
    }

    if ( scalar(@JobList) == 1 ) {
        return $Self->_Success(
            Job => $JobList[0],
        );
    }

    # return result
    return $Self->_Success(
        Job => \@JobList,
    );
}

sub _GetExecPlans {
    my ( $Self, %Param ) = @_;

    my @ExecPlans;
    if ( $Param{JobID}) {
        my @ExecPlanIDs = $Kernel::OM->Get('Automation')->JobExecPlanList(
            JobID => $Param{JobID},
        );

        # get already prepared ExecPlan data from ExecPlanGet operation
        if ( IsArrayRefWithData(\@ExecPlanIDs) ) {
            my $ExecPlanGetResult = $Self->ExecOperation(
                OperationType => 'V1::Automation::ExecPlanGet',
                Data          => {
                    ExecPlanID => join(',', sort @ExecPlanIDs)
                }
            );

            if ( IsHashRefWithData($ExecPlanGetResult) && $ExecPlanGetResult->{Success} ) {
                @ExecPlans = IsArrayRefWithData($ExecPlanGetResult->{Data}->{ExecPlan}) ?
                    @{$ExecPlanGetResult->{Data}->{ExecPlan}} : ( $ExecPlanGetResult->{Data}->{ExecPlan} );
            }
        }
    }
    return \@ExecPlans;
}

sub _GetMacros {
    my ( $Self, %Param ) = @_;

    my @Macros;
    if ( $Param{JobID}) {
        my @MacroIDs = $Kernel::OM->Get('Automation')->JobMacroList(
            JobID => $Param{JobID},
        );

        # get already prepared Macro data from MacroGet operation
        if ( IsArrayRefWithData(\@MacroIDs) ) {
            my $MacroGetResult = $Self->ExecOperation(
                OperationType => 'V1::Automation::MacroGet',
                Data          => {
                    MacroID => join(',', sort @MacroIDs)
                }
            );

            if ( IsHashRefWithData($MacroGetResult) && $MacroGetResult->{Success} ) {
                @Macros = IsArrayRefWithData($MacroGetResult->{Data}->{Macro}) ?
                    @{$MacroGetResult->{Data}->{Macro}} : ( $MacroGetResult->{Data}->{Macro} );

                # "include" actions - dynamic sub-resource include does not work, because it is no sub-resource hereof
                for my $Macro ( @Macros ) {
                    my $MacroActionSearchResult = $Self->ExecOperation(
                        OperationType => 'V1::Automation::MacroActionSearch',
                        Data          => {
                            MacroID => $Macro->{ID}
                        }
                    );
                    if ( !IsHashRefWithData($MacroActionSearchResult) || !$MacroActionSearchResult->{Success} || !IsHashRefWithData($MacroActionSearchResult->{Data}) ) {
                        $Macro->{Actions} = [];
                    } else {
                        $Macro->{Actions} = (ref $MacroActionSearchResult->{Data}->{MacroAction} eq 'ARRAY') ?
                            $MacroActionSearchResult->{Data}->{MacroAction} : [ $MacroActionSearchResult->{Data}->{MacroAction} ]
                    }
                }
            }
        }
    }
    return \@Macros;
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
