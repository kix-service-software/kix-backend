# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::JobRunSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Automation::JobRunSearch - API JobRun Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

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
    }
}

=item Run()

perform JobRunSearch Operation. This will return a list of runs for the given Job.

    my $Result = $OperationObject->Run(
        Data => {
            JobID => 123
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            JobRun => [
                {}
                {}
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @JobRunDataList;

    my %JobRunList = $Kernel::OM->Get('Kernel::System::Automation')->JobRunList(
        JobID => $Param{Data}->{JobID},
    );

    # get already prepared Run data from JobRunGet operation
    if ( IsHashRefWithData(\%JobRunList) ) {   
        my $JobRunGetResult = $Self->ExecOperation(
            OperationType            => 'V1::Automation::JobRunGet',
            SuppressPermissionErrors => 1,
            Data      => {
                JobID => $Param{Data}->{JobID},
                RunID => join(',', sort keys %JobRunList),
            }
        );    

        if ( !IsHashRefWithData($JobRunGetResult) || !$JobRunGetResult->{Success} ) {
            return $JobRunGetResult;
        }
        push @JobRunDataList, IsArrayRefWithData($JobRunGetResult->{Data}->{JobRun}) ? @{$JobRunGetResult->{Data}->{JobRun}} : ( $JobRunGetResult->{Data}->{JobRun} );
    }	            	
    
    if ( IsArrayRefWithData(\@JobRunDataList) ) {
        return $Self->_Success(
            JobRun => \@JobRunDataList,
        )
    }

    # return result
    return $Self->_Success(
        JobRun => [],
    );
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
