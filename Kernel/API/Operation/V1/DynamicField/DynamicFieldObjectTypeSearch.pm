# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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

    my $ObjectTypeConfig = $Kernel::OM->Get('Config')->Get('DynamicFields::ObjectType');

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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
