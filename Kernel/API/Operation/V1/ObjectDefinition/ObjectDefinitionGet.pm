# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ObjectDefinition::ObjectDefinitionGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ObjectDefinition::ObjectDefinitionGet - API ObjectDefinitionGet Operation backend

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
        'ObjectType' => {
            Type     => 'ARRAY',
            Required => 1
        }                
    }
}

=item Run()

perform ObjectDefinitionGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        ObjectType => 'Ticket'                            # required
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

    my @ObjectDefinitionList;
    foreach my $ObjectType (@{$Param{Data}->{ObjectType}}) {
        my $ObjectDefinition = $Kernel::OM->GetObjectDefinition($ObjectType);

        if (!$ObjectDefinition) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "Could not get object definition for '$ObjectType'",
            );        
        }

        push(@ObjectDefinitionList, $ObjectDefinition);
    }

    if ( scalar(@ObjectDefinitionList) == 1 ) {
        return $Self->_Success(
            ObjectDefinition => $ObjectDefinitionList[0],
        );    
    }

    # return result
    return $Self->_Success(
        ObjectDefinition => \@ObjectDefinitionList,
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
