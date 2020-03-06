# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::User::UserGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::User::UserGet - API User Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::User::UserGet->new();

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

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::User::UserGet');

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
        'UserID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }                
    }
}

=item Run()

perform UserGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            UserID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '...'
        Message      => '',                               # In case of an error
        Data         => {
            User => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @UserList;

    # start loop
    foreach my $UserID ( @{$Param{Data}->{UserID}} ) {

        # get the user data
        my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID        => $UserID,
            NoPreferences => 1
        );

        if ( !IsHashRefWithData( \%UserData ) ) {

            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeWhitelist}) ) {
            foreach my $Attr (sort keys %UserData) {
                delete $UserData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
            }
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeBlacklist}) ) {
            foreach my $Attr (sort keys %UserData) {
                delete $UserData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
            }
        }

        #FIXME: workaoround KIX2018-3308###########
        $Self->AddCacheDependency(Type => 'Contact');
        my %ContactData = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
            UserID => $UserID,
        );
        $UserData{UserFirstname} = %ContactData ? $ContactData{Firstname} : undef;
        $UserData{UserLastname} = %ContactData ? $ContactData{Lastname} : undef;
        $UserData{UserFullname} = %ContactData ? $ContactData{Fullname} : undef;
        $UserData{UserEmail} = %ContactData ? $ContactData{Email} : undef;
        ##################################

        #FIXME: comment back in when 3308 is resolved properly
        if ($Param{Data}->{include}->{Contact}) {
            # $Self->AddCacheDependency( Type => 'Contact' );
            $UserData{Contact} = undef;
            # my %ContactData = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
            #         UserID => $UserID,
            # );
            $UserData{Contact} = (%ContactData) ? \%ContactData : undef;
        }
                
        # add
        push(@UserList, \%UserData);
    }

    if ( scalar(@UserList) == 1 ) {
        return $Self->_Success(
            User => $UserList[0],
        );    
    }

    return $Self->_Success(
        User => \@UserList,
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
