# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ObjectSearch::SupportedAttributesSearch;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ObjectSearch::SupportedAttributesSearch - API ObjectSearch supported attributes search Operation backend

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

    return {}
}

=item Run()

perform SupportedSearch Operation. This function is able to return
one SupportedSearchesult entry in one call.

    my $Result = $OperationObject->Run(
        Data => {},
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            SupportedAttributes => {}
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Types = $Kernel::OM->Get('Config')->Get('Object::Types');

    my @AllowTypes;
    for my $Key ( sort keys %{$Types} ) {
        next if !$Types->{$Key};
        push( @AllowTypes, $Key );
    }

    if ( @AllowTypes ) {
        my $GetResult = $Self->ExecOperation(
            OperationType => 'V1::ObjectSearch::SupportedAttributesGet',
            Data          => {
                ObjectType => join(q{,}, @AllowTypes),
            }
        );

        if (
            !IsHashRefWithData($GetResult)
            || !$GetResult->{Success}
        ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{SupportedAttributes} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{SupportedAttributes})
                ? @{$GetResult->{Data}->{SupportedAttributes}}
                : ( $GetResult->{Data}->{SupportedAttributes} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                SupportedAttributes => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        SupportedAttributes => [],
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
