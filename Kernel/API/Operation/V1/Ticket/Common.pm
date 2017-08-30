# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::Common;

use strict;
use warnings;

use MIME::Base64();
use Mail::Address;

use Kernel::System::VariableCheck qw(:all);

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

    # check needed
    if ( !$Param{WebserviceID} ) {
        return {
            Success      => 0,
            ErrorMessage => "Got no WebserviceID!",
        };
    }

    # get webservice configuration
    my $Webservice = $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceGet(
        ID => $Param{WebserviceID},
    );

    if ( !IsHashRefWithData($Webservice) ) {
        return {
            Success => 0,
            ErrorMessage =>
                'Could not determine Web service configuration'
                . ' in Kernel::API::Operation::V1::Ticket::Common::new()',
        };
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

    return {
        Success => 1,
    };
}

=item ValidateCustomerService()

checks if the given service or service ID is valid for this customer / customer contact.

    my $Success = $CommonObject->ValidateService(
        ServiceID    => 123,
        CustomerUser => 'Test',
    );

    my $Success = $CommonObject->ValidateService(
        Service      => 'some service',
        CustomerUser => 'Test',
    );

    returns
    $Success = 1            # or 0

=cut

sub ValidateCustomerService {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{ServiceID} && !$Param{Service};
    return if !$Param{CustomerUser};

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
    my %CustomerServices = $ServiceObject->CustomerUserServiceMemberList(
        CustomerUserLogin => $Param{CustomerUser},
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
            return {
                Success      => 0,
                ErrorMessage => "SetDynamicFieldValue() Invalid value for $Needed, just string is allowed!"
            };
        }
    }

    # check value structure
    if ( !IsString( $Param{Value} ) && ref $Param{Value} ne 'ARRAY' ) {
        return {
            Success      => 0,
            ErrorMessage => "SetDynamicFieldValue() Invalid value for Value, just string and array are allowed!"
        };
    }

    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );

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
        return {
            Success      => 0,
            ErrorMessage => "SetDynamicFieldValue() Could not set $ObjectID!",
        };
    }

    my $Success = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicFieldConfig,
        ObjectID           => $ObjectID,
        Value              => $Param{Value},
        UserID             => $Param{UserID},
    );

    return {
        Success => $Success,
        }
}

=item CreateAttachment()

cretes a new attachment for the given article.

    my $Result = $CommonObject->CreateAttachment(
        Content     => $Data,                   # file content (Base64 encoded)
        ContentType => 'some content type',
        Filename    => 'some filename',
        ArticleID   => 456,
        UserID      => 123.
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

sub CreateAttachment {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Attachment ArticleID UserID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "CreateAttachment() Got no $Needed!"
            };
        }
    }

    # write attachment
    my $Success = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleWriteAttachment(
        %{ $Param{Attachment} },
        Content   => MIME::Base64::decode_base64( $Param{Attachment}->{Content} ),
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );

    return {
        Success => $Success,
        }
}

=item CheckCreatePermissions ()

Tests if the user have the permissions to create a ticket on a determined queue

    my $Result = $CommonObject->CheckCreatePermissions(
        Ticket     => $TicketHashReference,
        UserID     => 123,                      # or 'CustomerLogin'
        UserType   => 'Agent',                  # or 'Customer'
    );

returns:
    $Success = 1                                # if everything is OK

=cut

sub CheckCreatePermissions {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Ticket UserID UserType)) {
        if ( !$Param{$Needed} ) {
            return;
        }
    }

    # get create permission groups
    my %UserGroups;

    if ( $Param{UserType} ne 'Customer' ) {
        %UserGroups = $Kernel::OM->Get('Kernel::System::Group')->PermissionUserGet(
            UserID => $Param{UserID},
            Type   => 'create',
        );
    }
    else {
        %UserGroups = $Kernel::OM->Get('Kernel::System::CustomerGroup')->GroupMemberList(
            UserID => $Param{UserID},
            Type   => 'create',
            Result => 'HASH',
        );
    }

    my %QueueData;
    if ( defined $Param{Ticket}->{Queue} && $Param{Ticket}->{Queue} ne '' ) {
        %QueueData = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet( Name => $Param{Ticket}->{Queue} );
    }
    else {
        %QueueData = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet( ID => $Param{Ticket}->{QueueID} );
    }

    # permission check, can we create new tickets in queue
    return if !$UserGroups{ $QueueData{GroupID} };

    return 1;
}

=item CheckAccessPermissions()

Tests if the user have access permissions over a ticket

    my $Result = $CommonObject->CheckAccessPermissions(
        TicketID   => 123,
        UserID     => 123,                      # or 'CustomerLogin'
        UserType   => 'Agent',                  # or 'Customer'
    );

returns:
    $Success = 1                                # if everything is OK

=cut

sub CheckAccessPermissions {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID UserType)) {
        if ( !$Param{$Needed} ) {
            return;
        }
    }

    my $TicketPermissionFunction = 'TicketPermission';
    if ( $Param{UserType} eq 'Customer' ) {
        $TicketPermissionFunction = 'TicketCustomerPermission';
    }

    my $Access = $Kernel::OM->Get('Kernel::System::Ticket')->$TicketPermissionFunction(
        Type     => 'ro',
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );

    return $Access;
}

=begin Internal:

=item _CharsetList()

returns a list of all available charsets.

    my $CharsetList = $CommonObject->_CharsetList(
        UserID => 123,
    );

    returns
    $Success = {
        #...
        iso-8859-1  => 1,
        iso-8859-15 => 1,
        MacRoman    => 1,
        utf8        => 1,
        #...
    }

=cut

sub _CharsetList {
    my ( $Self, %Param ) = @_;

    # get charset array
    use Encode;
    my @CharsetList = Encode->encodings(":all");

    my %CharsetHash;

    # create a charset lookup table
    for my $Charset (@CharsetList) {
        $CharsetHash{$Charset} = 1;
    }

    return \%CharsetHash;
}

1;

=end Internal:




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
