# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ClientRegistration::ClientRegistrationCreate;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ClientRegistration::ClientRegistrationCreate - API ClientRegistration Create Operation backend

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
        'ClientRegistration' => {
            Type => 'HASH',
            Required => 1
        },
        'ClientRegistration::ClientID' => {
            Required => 1
        },
    }
}

=item Run()

perform ClientRegistrationCreate Operation. This will return the created ClientRegistrationID.

    my $Result = $OperationObject->Run(
        Data => {
            ClientRegistration => {
                ClientID         => '...',
                CallbackURL      => '...',        # optional
                CallbackInterval => '...',        # optional
                Authorization   => '...',         # optional
                Translations     => [             # optional
                    {
                        Language => 'de',
                        POFile   => '...'       # base64 encoded content of the PO file
                    }
                ]
            }
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ClientID  => '',                        # ID of the created ClientRegistration
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ClientRegistration parameter
    my $ClientRegistration = $Self->_Trim(
        Data => $Param{Data}->{ClientRegistration},
    );

    # check if ClientRegistration exists
    my %ClientRegistration = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationGet(
        ClientID => $ClientRegistration->{ClientID},
        Silent   => 1
    );

    if ( IsHashRefWithData(\%ClientRegistration) ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create client registration. A registration for the given ClientID already exists.",
        );
    }

    # create ClientRegistration
    my $ClientID = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationAdd(
        ClientID             => $ClientRegistration->{ClientID},
        NotificationURL      => $ClientRegistration->{NotificationURL},
        NotificationInterval => $ClientRegistration->{NotificationInterval},
        Authorization        => $ClientRegistration->{Authorization},
    );

    if ( !$ClientID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create client registration, please contact the system administrator',
        );
    }

    # import translations if given
    if ( IsArrayRefWithData($ClientRegistration->{Translations}) ) {
        foreach my $Item ( @{$ClientRegistration->{Translations}} ) {
            my $Content = MIME::Base64::decode_base64($Item->{Content});
                        
            # fire & forget, not result handling at the moment
            my $Result = $Kernel::OM->Get('Translation')->ImportPO(
                Language => $Item->{Language},
                Content  => $Content,
                UserID   => $Self->{Authorization}->{UserID},
            );
        }
    }

    # import SysConfig definitions if given
    if ( IsArrayRefWithData($ClientRegistration->{SysConfigOptionDefinitions}) ) {
        my %SysConfigOptions = $Kernel::OM->Get('SysConfig')->OptionGetAll();

        foreach my $Item ( @{$ClientRegistration->{SysConfigOptionDefinitions}} ) {
            if ( !exists $SysConfigOptions{$Item->{Name}} ) {
                # create new option
                my $Success = $Kernel::OM->Get('SysConfig')->OptionAdd(
                    Name            => $Item->{Name},
                    AccessLevel     => $Item->{AccessLevel},
                    Type            => $Item->{Type},
                    Context         => $Item->{Context},
                    ContextMetadata => $Item->{ContextMetadata},
                    Description     => $Item->{Description},
                    Comment         => $Item->{Comment},
                    Level           => $Item->{Level},
                    Group           => $Item->{Group},
                    IsRequired      => $Item->{IsRequired},
                    Setting         => $Item->{Setting},
                    Default         => $Item->{Default},
                    DefaultValidID  => $Item->{DefaultValidID},
                    UserID          => $Self->{Authorization}->{UserID},
                );

                if ( !$Success ) {
                    return $Self->_Error(
                        Code    => 'Object.UnableToCreate',
                        Message => 'Could not create SysConfigOptionDefinition "'.$Item->{Name}.'", please contact the system administrator',
                    );
                }
            }
            else {
                # update existing option
                my $Success = $Kernel::OM->Get('SysConfig')->OptionUpdate(
                    %{ $SysConfigOptions{ $Item->{Name} } },
                    %{$Item},
                    Value  => $SysConfigOptions{ $Item->{Name} }->{IsModified} ? $SysConfigOptions{ $Item->{Name} }->{Value} : undef,
                    UserID => $Self->{Authorization}->{UserID},
                );

                if ( !$Success ) {
                    return $Self->_Error(
                        Code => 'Object.UnableToUpdate',
                        Message => 'Could not update SysConfigOptionDefinition "'.$Item->{Name}.'", please contact the system administrator',
                    );
                }
            }
        }
    }

    my %SystemInfo;
    foreach my $Key ( qw(Product Version BuildDate BuildHost BuildNumber) ) {
        $SystemInfo{$Key} = $Kernel::OM->Get('Config')->Get($Key);
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        ClientID => $ClientID,
        SystemInfo => \%SystemInfo,
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
