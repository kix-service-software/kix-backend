# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::Common;

use strict;
use warnings;

use MIME::Base64();
use Mail::Address;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::Common - Base class for all Ticket Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Init()

initialize the operation by checking the webservice configuration and gather of the dynamic fields

    my $Return = $CommonObject->Init(
        WebserviceID => 1,
    );

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        ErrorMessage => 'Error Message',
    }

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    my $InitResult = $Self->SUPER::Init(%Param);

    if ( !$InitResult->{Success} ) {
        return $InitResult;
    }

    # get the dynamic fields
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => [ 'Ticket', 'Article' ],
    );

    # create a Dynamic Fields lookup table (by name)
    DYNAMICFIELD:
    for my $DynamicField ( @{$DynamicField} ) {
        next DYNAMICFIELD if !$DynamicField;
        next DYNAMICFIELD if !IsHashRefWithData($DynamicField);
        next DYNAMICFIELD if !$DynamicField->{Name};
        $Self->{DynamicFieldLookup}->{ $DynamicField->{Name} } = $DynamicField;
    }

    return $Self->_Success();
}

=item ValidateCustomerService()

checks if the given service or service ID is valid for this customer / customer contact.

    my $Success = $CommonObject->ValidateService(
        ServiceID    => 123,
        Contact => 'Test',
    );

    my $Success = $CommonObject->ValidateService(
        Service      => 'some service',
        Contact => 'Test',
    );

    returns
    $Success = 1            # or 0

=cut

sub ValidateCustomerService {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{ServiceID} && !$Param{Service};
    return if !$Param{Contact};

    my %ServiceData;

    # get service object
    my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');

    # check for Service name sent
    if (
        $Param{Service}
        && $Param{Service} ne ''
        && !$Param{ServiceID}
        )
    {
        %ServiceData = $ServiceObject->ServiceGet(
            Name   => $Param{Service},
            UserID => 1,
        );
    }

    # otherwise use ServiceID
    elsif ( $Param{ServiceID} ) {
        %ServiceData = $ServiceObject->ServiceGet(
            ServiceID => $Param{ServiceID},
            UserID    => 1,
        );
    }
    else {
        return;
    }

    # return false if service data is empty
    return if !IsHashRefWithData( \%ServiceData );

    # return false if service is not valid
    if (
        $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup( ValidID => $ServiceData{ValidID} )
        ne 'valid'
        )
    {
        return;
    }

    # get customer services
    my %CustomerServices = $ServiceObject->ContactServiceMemberList(
        ContactLogin => $Param{Contact},
        Result            => 'HASH',
        DefaultServices   => 1,
    );

    # return if user does not have permission to use the service
    return if !$CustomerServices{ $ServiceData{ServiceID} };

    return 1;
}

=item ValidateServiceSLA()

checks if the given service or service ID is valid.

    my $Success = $CommonObject->ValidateSLA(
        SLAID     => 12,
        ServiceID => 123,       # || Service => 'some service'
    );

    my $Success = $CommonObject->ValidateService(
        SLA       => 'some SLA',
        ServiceID => 123,       # || Service => 'some service'
    );

    returns
    $Success = 1            # or 0

=cut

sub ValidateServiceSLA {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{SLAID}     && !$Param{SLA};
    return if !$Param{ServiceID} && !$Param{Service};

    my %SLAData;

    # get SLA object
    my $SLAObject = $Kernel::OM->Get('Kernel::System::SLA');

    # check for SLA name sent
    if (
        $Param{SLA}
        && $Param{SLA} ne ''
        && !$Param{SLAID}
        )
    {
        my $SLAID = $SLAObject->SLALookup(
            Name => $Param{SLA},
        );
        %SLAData = $SLAObject->SLAGet(
            SLAID  => $SLAID,
            UserID => 1,
        );
    }

    # otherwise use SLAID
    elsif ( $Param{SLAID} ) {
        %SLAData = $SLAObject->SLAGet(
            SLAID  => $Param{SLAID},
            UserID => 1,
        );
    }
    else {
        return;
    }

    # return false if SLA data is empty
    return if !IsHashRefWithData( \%SLAData );

    # return false if SLA is not valid
    if (
        $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup( ValidID => $SLAData{ValidID} )
        ne 'valid'
        )
    {
        return;
    }

    # get service ID
    my $ServiceID;
    if (
        $Param{Service}
        && $Param{Service} ne ''
        && !$Param{ServiceID}
        )
    {
        $ServiceID = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup( Name => $Param{Service} )
            || 0;
    }
    else {
        $ServiceID = $Param{ServiceID} || 0;
    }

    return if !$ServiceID;

    # check if SLA belongs to service
    my $SLABelongsToService;

    SERVICEID:
    for my $SLAServiceID ( @{ $SLAData{ServiceIDs} } ) {
        next SERVICEID if !$SLAServiceID;
        if ( $SLAServiceID eq $ServiceID ) {
            $SLABelongsToService = 1;
            last SERVICEID;
        }
    }

    # return if SLA does not belong to the service
    return if !$SLABelongsToService;

    return 1;
}

=item ValidatePendingTime()

checks if the given pending time is valid.

    my $Success = $CommonObject->ValidatePendingTime(
        PendingTime => {
            Year   => 2011,
            Month  => 12,
            Day    => 23,
            Hour   => 15,
            Minute => 0,
        },
    );

    my $Success = $CommonObject->ValidatePendingTime(
        PendingTime => {
            Diff => 10080,
        },
    );

    returns
    $Success = 1            # or 0

=cut

sub ValidatePendingTime {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{PendingTime};
    return if !IsHashRefWithData( $Param{PendingTime} );

    # if only the Diff attribute is present, check if it's a valid number and return.
    # Nothing else needs to be checked in that case.
    if ( keys %{ $Param{PendingTime} } == 1 && defined $Param{PendingTime}->{Diff} ) {
        return if $Param{PendingTime}->{Diff} !~ m{\A \d+ \z}msx;
        return 1;
    }
    elsif ( defined $Param{PendingTime}->{Diff} ) {

        # the use of Diff along with any other option is forbidden
        return;
    }

    # check that no time attribute is empty or negative
    for my $TimeAttribute ( sort keys %{ $Param{PendingTime} } ) {
        return if $Param{PendingTime}->{$TimeAttribute} eq '';
        return if int $Param{PendingTime}->{$TimeAttribute} < 0,
    }

    # try to convert pending time to a SystemTime
    my $SystemTime = $Kernel::OM->Get('Kernel::System::Time')->Date2SystemTime(
        %{ $Param{PendingTime} },
        Second => 0,
    );
    return if !$SystemTime;

    return 1;
}

=item ValidateDynamicFieldName()

checks if the given dynamic field name is valid.

    my $Success = $CommonObject->ValidateDynamicFieldName(
        Name => 'some name',
    );

    returns
    $Success = 1            # or 0

=cut

sub ValidateDynamicFieldName {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );
    return if !$Param{Name};

    return if !$Self->{DynamicFieldLookup}->{ $Param{Name} };
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup}->{ $Param{Name} } );

    return 1;
}

=item ValidateDynamicFieldValue()

checks if the given dynamic field value is valid.

    my $Success = $CommonObject->ValidateDynamicFieldValue(
        Name  => 'some name',
        Value => 'some value',          # String or Integer or DateTime format
    );

    my $Success = $CommonObject->ValidateDynamicFieldValue(
        Value => [                      # Only for fields that can handle multiple values like
            'some value',               #   Multiselect
            'some other value',
        ],
    );

    returns
    $Success = 1                        # or 0

=cut

sub ValidateDynamicFieldValue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );

    # possible structures are string and array, no data inside is needed
    if ( !IsString( $Param{Value} ) && ref $Param{Value} ne 'ARRAY' ) {
        return;
    }

    # get dynamic field config
    my $DynamicFieldConfig = $Self->{DynamicFieldLookup}->{ $Param{Name} };

    my $ValueType = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->ValueValidate(
        DynamicFieldConfig => $DynamicFieldConfig,
        Value              => $Param{Value},
        UserID             => 1,
    );

    return $ValueType;
}

=item ValidateDynamicFieldObjectType()

checks if the given dynamic field name is valid.

    my $Success = $CommonObject->ValidateDynamicFieldObjectType(
        Name    => 'some name',
        Article => 1,               # if article exists
    );

    returns
    $Success = 1            # or 0

=cut

sub ValidateDynamicFieldObjectType {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );
    return if !$Param{Name};

    return if !$Self->{DynamicFieldLookup}->{ $Param{Name} };
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup}->{ $Param{Name} } );

    my $DynamicFieldConfg = $Self->{DynamicFieldLookup}->{ $Param{Name} };
    return if $DynamicFieldConfg->{ObjectType} eq 'Article' && !$Param{Article};

    return 1;
}

=item SetDynamicFieldValue()

sets the value of a dynamic field.

    my $Result = $CommonObject->SetDynamicFieldValue(
        Name      => 'some name',           # the name of the dynamic field
        Value     => 'some value',          # String or Integer or DateTime format
        TicketID  => 123
        ArticleID => 123
        UserID => 123,
    );

    my $Result = $CommonObject->SetDynamicFieldValue(
        Name   => 'some name',           # the name of the dynamic field
        Value => [
            'some value',
            'some other value',
        ],
        UserID => 123,
    );

    returns
    $Result = {
        Success => 1,                        # if everything is ok
    }

    $Result = {
        Success      => 0,
        ErrorMessage => 'Error description'
    }

=cut

sub SetDynamicFieldValue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Name UserID)) {
        if ( !IsString( $Param{$Needed} ) ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "SetDynamicFieldValue() Invalid value for $Needed, just string is allowed!"
            );
        }
    }

    # check value structure
    if ( !IsString( $Param{Value} ) && ref $Param{Value} ne 'ARRAY' && defined($Param{Value}) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => "SetDynamicFieldValue() Invalid value for Value, just string, array and undef is allowed!"
        );
    }

    if ( !IsHashRefWithData( $Self->{DynamicFieldLookup} ) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => "SetDynamicFieldValue() No DynamicFieldLookup!"
        );
    }

    # get dynamic field config
    my $DynamicFieldConfig = $Self->{DynamicFieldLookup}->{ $Param{Name} };

    my $ObjectID;
    if ( $DynamicFieldConfig->{ObjectType} eq 'Ticket' ) {
        $ObjectID = $Param{TicketID} || '';
    }
    else {
        $ObjectID = $Param{ArticleID} || '';
    }

    if ( !$ObjectID ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => "SetDynamicFieldValue() missing ObjectID!"
        );
    }

    my $Success = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicFieldConfig,
        ObjectID           => $ObjectID,
        Value              => $Param{Value},
        UserID             => $Param{UserID},
    );

    return $Self->_Success();
}

=begin Internal:

=item _CheckTicket()

checks if the given ticket parameter is valid.

    my $TicketCheck = $OperationObject->_CheckTicket(
        Ticket => $Ticket,                        # all ticket parameters
    );

    returns:

    $TicketCheck = {
        Success => 1,                               # if everything is OK
    }

    $TicketCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckTicket {
    my ( $Self, %Param ) = @_;

    my $Ticket = $Param{Ticket};

    # check ticket internally
    for my $Needed (qw(Title)) {
        if ( !$Ticket->{$Needed} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Required parameter $Needed is missing!",
            );
        }
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    if ( defined $Ticket->{Articles} ) {

        if ( !IsArrayRefWithData($Ticket->{Articles}) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Ticket::Articles is invalid!",
            );            
        }

        # check Article internal structure
        foreach my $ArticleItem (@{$Ticket->{Articles}}) {
            if ( !IsHashRefWithData($ArticleItem) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter Ticket::Articles is invalid!",
                );
            }

            # check article attribute values
            my $ArticleCheck = $Self->_CheckArticle( Article => $ArticleItem );

            if ( !$ArticleCheck->{Success} ) {
                return $Self->_Error( 
                    %{$ArticleCheck} 
                );
            }
        }
    }

    if ( defined $Ticket->{DynamicField} ) {

        if ( !IsArrayRefWithData($Ticket->{DynamicFields}) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Ticket::DynamicFields is invalid!",
            );            
        }

        # check DynamicField internal structure
        foreach my $DynamicFieldItem (@{$Ticket->{DynamicFields}}) {
            if ( !IsHashRefWithData($DynamicFieldItem) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter Ticket::DynamicFields is invalid!",
                );
            }

            # check DynamicField attribute values
            my $DynamicFieldCheck = $Self->_CheckDynamicField( DynamicField => $DynamicFieldItem );

            if ( !$DynamicFieldCheck->{Success} ) {
                return $Self->_Error( 
                    %{$DynamicFieldCheck} 
                );
            }
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _CheckArticle()

checks if the given article parameter is valid.

    my $ArticleCheck = $OperationObject->_CheckArticle(
        Article => $Article,                        # all article parameters
    );

    returns:

    $ArticleCheck = {
        Success => 1,                               # if everything is OK
    }

    $ArticleCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckArticle {
    my ( $Self, %Param ) = @_;

    my $Article = $Param{Article};

    # check ticket internally
    for my $Needed (qw(Subject Body)) {
        if ( !$Article->{$Needed} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Required parameter $Needed is missing!",
            );
        }
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check Article->TimeUnit
    # TimeUnit could be required or not depending on sysconfig option
    if (
        ( !defined $Article->{TimeUnit} || !IsStringWithData( $Article->{TimeUnit} ) )
        && $ConfigObject->{'Ticket::Frontend::AccountTime'}
        && $ConfigObject->{'Ticket::Frontend::NeedAccountedTime'}
        )
    {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Required parameter TimeUnit is missing!",
        );
    }
    if ( $Article->{TimeUnit} ) {
        if ( !$Self->ValidateTimeUnit( %{$Article} ) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter TimeUnit is invalid!",
            );
        }
    }

    # check Article->NoAgentNotify
    if ( $Article->{NoAgentNotify} && $Article->{NoAgentNotify} ne '1' ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Parameter NoAgentNotify is invalid!",
        );
    }

    # check Article array parameters
    for my $Attribute (
        qw( ForceNotificationToUserID ExcludeNotificationToUserID ExcludeMuteNotificationToUserID )
        )
    {
        if ( defined $Article->{$Attribute} ) {

            # check structure
            if ( IsHashRefWithData( $Article->{$Attribute} ) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter $Attribute is invalid!",
                );
            }
            else {
                if ( !IsArrayRefWithData( $Article->{$Attribute} ) ) {
                    $Article->{$Attribute} = [ $Article->{$Attribute} ];
                }
                for my $UserID ( @{ $Article->{$Attribute} } ) {
                    if ( !$Self->ValidateUserID( UserID => $UserID ) ) {
                        return $Self->_Error(
                            Code    => 'BadRequest',
                            Message => "Parameter UserID $UserID in parameter $Attribute is invalid!",
                        );
                    }
                }
            }
        }
    }

    if ( defined $Article->{Attachments} ) {

        if ( !IsArrayRefWithData($Article->{Attachments}) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Article::Attachments is invalid!",
            );            
        }

        # check Attachment internal structure
        foreach my $AttachmentItem (@{$Article->{Attachments}}) {
            if ( !IsHashRefWithData($AttachmentItem) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter Article::Attachments is invalid!",
                );
            }

            # check Attachment attribute values
            my $AttachmentCheck = $Self->_CheckAttachment( Attachment => $AttachmentItem );

            if ( !$AttachmentCheck->{Success} ) {
                return $Self->_Error( 
                    %{$AttachmentCheck} 
                );
            }
        }
    }

    if ( defined $Article->{DynamicField} ) {

        if ( !IsArrayRefWithData($Article->{DynamicFields}) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Article::DynamicFields is invalid!",
            );            
        }

        # check DynamicField internal structure
        foreach my $DynamicFieldItem (@{$Article->{DynamicFields}}) {
            if ( !IsHashRefWithData($DynamicFieldItem) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter Article::DynamicFields is invalid!",
                );
            }

            # check DynamicField attribute values
            my $DynamicFieldCheck = $Self->_CheckDynamicField( DynamicField => $DynamicFieldItem );

            if ( !$DynamicFieldCheck->{Success} ) {
                return $Self->_Error( 
                    %{$DynamicFieldCheck} 
                );
            }
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _CheckDynamicField()

checks if the given dynamic field parameter is valid.

    my $DynamicFieldCheck = $OperationObject->_CheckDynamicField(
        DynamicField => $DynamicField,              # all dynamic field parameters
    );

    returns:

    $DynamicFieldCheck = {
        Success => 1,                               # if everything is OK
    }

    $DynamicFieldCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckDynamicField {
    my ( $Self, %Param ) = @_;

    my $DynamicField = $Param{DynamicField};

    # check DynamicField item internally
    for my $Needed (qw(Name Value)) {
        if (
            !defined $DynamicField->{$Needed}
            || ( !IsString( $DynamicField->{$Needed} ) && ref $DynamicField->{$Needed} ne 'ARRAY' )
            )
        {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter DynamicField::$Needed is missing!",
            );
        }
    }

    # check DynamicField->Name
    if ( !$Self->ValidateDynamicFieldName( %{$DynamicField} ) ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Parameter DynamicField::Name is invalid!",
        );
    }

    # check DynamicField->Value
    if ( !$Self->ValidateDynamicFieldValue( %{$DynamicField} ) ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Parameter DynamicField::Value is invalid!",
        );
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _CheckAttachment()

checks if the given attachment parameter is valid.

    my $AttachmentCheck = $OperationObject->_CheckAttachment(
        Attachment => $Attachment,                  # all attachment parameters
    );

    returns:

    $AttachmentCheck = {
        Success => 1,                               # if everything is OK
    }

    $AttachmentCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckAttachment {
    my ( $Self, %Param ) = @_;

    my $Attachment = $Param{Attachment};

    # check attachment item internally
    for my $Needed (qw(ContentType Filename Content)) {
        if ( !$Attachment->{$Needed} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Attachment::$Needed is missing!",
            );
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
