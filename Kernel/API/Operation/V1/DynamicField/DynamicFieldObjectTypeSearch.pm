# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::DynamicField::DynamicFieldObjectTypeSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::DynamicField::DynamicFieldObjectTypeSearch - API DynamicField Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $ObjectType, %Param ) = @_;

    my $Self = {};
    bless( $Self, $ObjectType );

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

=item Run()

perform DynamicFieldObjectTypeSearch Operation. This will return a list of DynamicField ObjectTypes.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            DynamicFieldObject => [
                { },
                { },
                ...
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $ObjectTypeConfig = $Kernel::OM->Get('Kernel::Config')->Get('DynamicFields::ObjectType');

    if ( !IsHashRefWithData($ObjectTypeConfig) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => 'DynamicField::ObjectType config is not valid',
        );
    }

    my @ObjectTypes;
    for my $ObjectType ( sort keys %{$ObjectTypeConfig} ) {
        push(@ObjectTypes, {
            Name        => $ObjectType,
            DisplayName => $ObjectTypeConfig->{$ObjectType}->{DisplayName},
        });
    }

    if ( scalar(@ObjectTypes) == 1 ) {
        return $Self->_Success(
            DynamicFieldObject => $ObjectTypes[0],
        );
    }

    # return result
    return $Self->_Success(
        DynamicFieldObject => \@ObjectTypes,
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
