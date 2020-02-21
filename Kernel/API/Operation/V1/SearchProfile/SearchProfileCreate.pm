# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SearchProfile::SearchProfileCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::SearchProfile::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SearchProfile::SearchProfileCreate - API SearchProfile Create Operation backend

=head1 SYNOPSIS

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
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
        'SearchProfile' => {
            Type     => 'HASH',
            Required => 1
        },
        'SearchProfile::Type' => {
            Required => 1
        },            
        'SearchProfile::Name' => {
            Required => 1
        },            
        'SearchProfile::UserLogin' => {
            Required => 1
        },
        'SearchProfile::UserType' => {
            Required => 1,
            OneOf    => [
                'Agent',
                'Customer'
            ]
        },
        'SearchProfile::SubscribedProfileID' => {
            RequiredIfNot => [ 'SearchProfile::Data' ],
        },
    }
}

=item Run()

perform SearchProfileCreate Operation. This will return the created SearchProfileID.

    my $Result = $OperationObject->Run(
        Data => {
            SearchProfile  => {
                Type                => 'Ticket',
                Name                => 'last-search',
                UserType            => 'Agent'|'Customer'
                UserLogin           => '...',
                SubscribedProfileID => 123,                 # optional, ID of the subscribed (referenced) search profile
                Data                => {                    # necessary if no subscription
                    Key => Value
                },
                Categories   => [                           # optional, if profile should be shared
                    '...'
                ]
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            SearchProfileID  => '',                 # ID of the created SearchProfile
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim SearchProfile parameter
    my $SearchProfile = $Self->_Trim(
        Data => $Param{Data}->{SearchProfile}
    );

    # check attribute values
    my $CheckResult = $Self->_CheckSearchProfile( 
        SearchProfile => $SearchProfile
    );

    if ( !$CheckResult->{Success} ) {
        return $Self->_Error(
            %{$CheckResult},
        );
    }

    # check if SearchProfile exists
    my @ExistingProfileIDs = $Kernel::OM->Get('Kernel::System::SearchProfile')->SearchProfileList(
        Type        => $SearchProfile->{Type},
        Name        => $SearchProfile->{Name},
        UserType    => $SearchProfile->{UserType},
        UserLogin   => $SearchProfile->{UserLogin},
    );
    
    if ( @ExistingProfileIDs ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create SearchProfile. A profile with the same name already exists for this type and user.",
        );
    }
    
    # create SearchProfile
    my $SearchProfileID = $Kernel::OM->Get('Kernel::System::SearchProfile')->SearchProfileAdd(
        Type              => $SearchProfile->{Type},
        Name                => $SearchProfile->{Name},
        UserType            => $SearchProfile->{UserType},
        UserLogin           => $SearchProfile->{UserLogin},
        SubscribedProfileID => $SearchProfile->{SubscribedProfileID},
        Data                => $SearchProfile->{Data},
        Categories          => $SearchProfile->{Categories},
        UserID              => $Self->{Authorization}->{UserID},
    );

    if ( !$SearchProfileID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create SearchProfile, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        SearchProfileID => $SearchProfileID,
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
