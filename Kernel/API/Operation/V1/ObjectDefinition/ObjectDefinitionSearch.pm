# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

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

        my @ObjectDefinitionDataList = IsArrayRefWithData($ObjectDefinitionGetResult->{Data}->{ObjectDefinition}) ? @{$ObjectDefinitionGetResult->{Data}->{ObjectDefinition}} : ( $ObjectDefinitionGetResult->{Data}->{ObjectDefinition} );

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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut