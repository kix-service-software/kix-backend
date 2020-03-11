# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ObjectDefinition::ObjectDefinitionSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ObjectDefinition::ObjectDefinitionSearch - API ObjectDefinitionSearch Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

perform ObjectDefinitionSearch Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            ObjectDefinition => [
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ObjectDefinitionList = $Kernel::OM->GetObjectDefinitionList();

	# get already prepared ObjectDefinition data from ObjectDefinitionGet operation
    if ( IsArrayRefWithData(\@ObjectDefinitionList) ) {  	
        my $ObjectDefinitionGetResult = $Self->ExecOperation(
            OperationType => 'V1::ObjectDefinition::ObjectDefinitionGet',
            Data      => {
                ObjectType => join(',', sort @ObjectDefinitionList),
            }
        );    

        if ( !IsHashRefWithData($ObjectDefinitionGetResult) || !$ObjectDefinitionGetResult->{Success} ) {
            return $ObjectDefinitionGetResult;
        }

        my @ObjectDefinitionDataList = IsArrayRef($ObjectDefinitionGetResult->{Data}->{ObjectDefinition}) ? @{$ObjectDefinitionGetResult->{Data}->{ObjectDefinition}} : ( $ObjectDefinitionGetResult->{Data}->{ObjectDefinition} );

        if ( IsArrayRefWithData(\@ObjectDefinitionDataList) ) {
            return $Self->_Success(
                ObjectDefinition => \@ObjectDefinitionDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ObjectDefinition => [],
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
