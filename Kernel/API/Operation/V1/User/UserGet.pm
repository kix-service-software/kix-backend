# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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

    if ( $Self->_CanRunParallel(Items => $Param{Data}->{UserID}) ) {
        @UserList = $Self->_RunParallel(
            \&_GetUserData,
            Items => $Param{Data}->{UserID},
            %Param,
        );
    }
    else {
        # start loop
        foreach my $UserID ( @{$Param{Data}->{UserID}} ) {

            my $UserData = $Self->_GetUserData(
                UserID => $UserID,
                Data   => $Param{Data}
            );
            if ( IsHashRefWithData($UserData) ) {
                push @UserList, $UserData;
            }
            else {
                return $Self->_Error(
                    Code => 'Object.NotFound',
                );
            }
        }
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

sub _GetUserData {
    my ( $Self, %Param ) = @_;

    my $UserID = $Param{Item} || $Param{UserID};

    # get the user data
    my %UserData = $Kernel::OM->Get('User')->GetUserData(
        UserID        => $UserID,
        NoPreferences => 1
    );

    if ( !IsHashRefWithData(\%UserData) ) {
        return;
    }

    # filter valid attributes
    if ( IsHashRefWithData($Self->{Config}->{AttributeWhitelist}) ) {
        foreach my $Attr ( sort keys %UserData ) {
            delete $UserData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
        }
    }

    # filter valid attributes
    if ( IsHashRefWithData($Self->{Config}->{AttributeBlacklist}) ) {
        foreach my $Attr ( sort keys %UserData ) {
            delete $UserData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
        }
    }

    #FIXME: workaoround KIX2018-3308###########
    $Self->AddCacheDependency(Type => 'Contact');
    my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
        UserID        => $UserID,
        DynamicFields => $Param{Data}->{include}->{DynamicFields},
    );
    $UserData{UserFirstname} = %ContactData ? $ContactData{Firstname} : undef;
    $UserData{UserLastname} = %ContactData ? $ContactData{Lastname} : undef;
    $UserData{UserFullname} = %ContactData ? $ContactData{Fullname} : undef;
    $UserData{UserEmail} = %ContactData ? $ContactData{Email} : undef;
    ##################################

    if ( $Param{Data}->{include}->{DynamicFields} ) {
        my @DynamicFields;

        # inform API caching about a new dependency
        $Self->AddCacheDependency(Type => 'DynamicField');

        # remove all dynamic fields from contact hash and set them into an array.
        ATTRIBUTE:
        for my $Attribute ( sort keys %ContactData ) {

            if ( $Attribute =~ m{\A DynamicField_(.*) \z}msx ) {
                if ( $ContactData{$Attribute} ) {
                    my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
                        Name => $1,
                    );
                    if ( IsHashRefWithData($DynamicFieldConfig) ) {

                        # ignore DFs which are not visible for the customer, if the user session is a Customer session
                        next ATTRIBUTE if $Self->{Authorization}->{UserType} eq 'Customer' && !$DynamicFieldConfig->{CustomerVisible};

                        my $PreparedValue = $Self->_GetPrepareDynamicFieldValue(
                            Config          => $DynamicFieldConfig,
                            Value           => $ContactData{$Attribute},
                            NoDisplayValues => [split(',', $Param{Data}->{NoDynamicFieldDisplayValues} || '')]
                        );

                        if ( IsHashRefWithData($PreparedValue) ) {
                            push(@DynamicFields, $PreparedValue);
                        }
                    }
                    delete $ContactData{$Attribute};
                }
                next ATTRIBUTE;
            }
        }

        # add dynamic fields array into 'DynamicFields' hash key if any
        if ( @DynamicFields ) {
            $ContactData{DynamicFields} = \@DynamicFields;
        }
        else {
            $ContactData{DynamicFields} = [];
        }
    }

    #FIXME: comment back in when 3308 is resolved properly
    if ( $Param{Data}->{include}->{Contact} ) {
        # $Self->AddCacheDependency( Type => 'Contact' );
        $UserData{Contact} = undef;
        # my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
        #         UserID => $UserID,
        # );
        $UserData{Contact} = ( %ContactData ) ? \%ContactData : undef;
    }

    return \%UserData;
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
