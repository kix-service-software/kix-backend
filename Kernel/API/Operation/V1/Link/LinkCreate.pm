# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Link::LinkCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Link::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Link::LinkCreate - API Link LinkCreate Operation backend

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
        'Link' => {
            Type     => 'HASH',
            Required => 1
        },
        'Link::SourceObject' => {
            Required => 1
        },
        'Link::SourceKey' => {
            Required => 1
        },
        'Link::TargetObject' => {
            Required => 1
        },
        'Link::TargetKey' => {
            Required => 1
        },
        'Link::Type' => {
            Required => 1
        },
    }
}

=item Run()

perform LinkCreate Operation. This will return the created LinkID.

    my $Result = $OperationObject->Run(
        Data => {
            Link  => {
                SourceObject => '...',
                SourceKey    => '...',
                TargetObject => '...',
                TargetKey    => '...',
                Type         => '...'
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            LinkID  => '',                         # ID of the created Link
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Link parameter
    my $Link = $Self->_Trim(
        Data => $Param{Data}->{Link}
    );

    # check attribute values
    my $CheckResult = $Self->_CheckLink(
        Link => $Link
    );

    if ( !$CheckResult->{Success} ) {
        return $Self->_Error(
            %{$CheckResult},
        );
    }

    # check if Link exists
    my $LinkList = $Kernel::OM->Get('LinkObject')->LinkSearch(
        %{$Link},
        UserID => $Self->{Authorization}->{UserID},
    );

    if ( IsArrayRefWithData($LinkList) ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create Link. A link with these parameters already exists.",
        );
    }

    # create Link
    my $LinkID = $Kernel::OM->Get('LinkObject')->LinkAdd(
        %{$Link},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$LinkID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Link, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        LinkID => $LinkID,
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
