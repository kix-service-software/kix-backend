# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::MacroActionSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Automation::MacroActionSearch - API MacroAction Search Operation backend

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
            MacroID => 123,
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'MacroID' => {
            Required => 1
        },
    }
}

=item Run()

perform MacroActionSearch Operation. This will return a MacroAction list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            MacroAction => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    
    my @MacroActionDataList;

    # check if macro exists
    my %Macro = $Kernel::OM->Get('Kernel::System::Automation')->MacroGet(
        ID => $Param{Data}->{MacroID},
    );

    if ( !%Macro ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    my %MacroActionList = $Kernel::OM->Get('Kernel::System::Automation')->MacroActionList(
        MacroID => $Param{Data}->{MacroID},
        Valid   => 0,
    );
   
    # get already prepared MacroAction data from MacroActionGet operation
    if ( IsHashRefWithData(\%MacroActionList) ) {   
        my $MacroActionGetResult = $Self->ExecOperation(
            OperationType => 'V1::Automation::MacroActionGet',
            Data      => {
                MacroID       => $Param{Data}->{MacroID},
                MacroActionID => join(',', sort keys %MacroActionList),
            }
        );    

        if ( !IsHashRefWithData($MacroActionGetResult) || !$MacroActionGetResult->{Success} ) {
            return $MacroActionGetResult;
        }
        push @MacroActionDataList,IsArrayRefWithData($MacroActionGetResult->{Data}->{MacroAction}) ? @{$MacroActionGetResult->{Data}->{MacroAction}} : ( $MacroActionGetResult->{Data}->{MacroAction} );
    }	            	

    if ( IsArrayRefWithData(\@MacroActionDataList) ) {
        return $Self->_Success(
            MacroAction => \@MacroActionDataList,
        )
    }
    
    # return result
    return $Self->_Success(
        MacroAction => [],
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
