# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleGet - API FAQArticle Get Operation backend

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
        'FAQArticleID' => {
            Type     => 'ARRAY',
            Required => 1
        }
    }
}

=item PreRun()

some code to run before actual execution

    my $Success = $CommonObject->PreRun(
        ...
    );

    returns:

    $Success = {
        Success => 1,                     # if everything is OK
    }

    $Success = {
        Code    => 'Forbidden',           # if error
        Message => 'Error description',
    }

=cut

sub PreRun {
    my ( $Self, %Param ) = @_;

    # filter faq article ids for customer
    if ($Param{Data}->{FAQArticleID}) {
        my @FAQArticleIDs = $Self->_FilterCustomerUserVisibleObjectIds(
            ObjectType             => 'FAQArticle',
            ObjectIDList           => $Param{Data}->{FAQArticleID},
            RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID},
            LogFiltered => 1
        );
        if (@FAQArticleIDs) {
            $Param{Data}->{FAQArticleID} = \@FAQArticleIDs;
        } else {
            return $Self->_Error(
                Code => 'Forbidden',
                Message => @{$Param{Data}->{FAQArticleID}} == 1 ?
                "Could not access FAQArticle with id $Param{Data}->{FAQArticleID}->[0]" :
                "Could not access any FAQArticle"
            );
        }
    }

    return $Self->_Success();
}


=item Run()

perform FAQArticleGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            FAQArticleID => 1,
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            FAQArticle => [
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

    my @FAQArticleData;

    # inform API caching about a new dependency
    $Self->AddCacheDependency(Type => 'DynamicField');

    # start loop
    foreach my $FAQArticleID ( @{$Param{Data}->{FAQArticleID}} ) {

        # get the FAQArticle data
        my %FAQArticle = $Kernel::OM->Get('FAQ')->FAQGet(
            ItemID     => $FAQArticleID,
            ItemFields => 1,
            UserID     => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%FAQArticle ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # map ItemID to ID
        $FAQArticle{ID} = $FAQArticle{ItemID};
        delete $FAQArticle{ItemID};

        # convert Keywords to array
        my @Keywords = split(/\s+/, $FAQArticle{Keywords} || '');
        $FAQArticle{Keywords} = \@Keywords;

        $FAQArticle{CustomerVisible} = $FAQArticle{Visibility}
            && ($FAQArticle{Visibility} eq 'external' || $FAQArticle{Visibility} eq 'public' )
            ? 1 : 0;
        delete $FAQArticle{Visibility};

        if ($Param{Data}->{include}->{DynamicFields}) {
            $FAQArticle{DynamicFields} = $Self->_GetDynamicFields(
                FAQArticleID => $FAQArticle{ID},
                Data         => $Param{Data},
            );
        }

        # add link count
        $FAQArticle{LinkCount} = 0 + $Kernel::OM->Get('LinkObject')->LinkCount(
            Object => 'FAQArticle',
            Key    => $FAQArticle{ID}
        );

        if ($Param{Data}->{include}->{Rating}) {
            my $VoteDataHashRef = $Kernel::OM->Get('FAQ')->ItemVoteDataGet(
                ItemID => $FAQArticle{ID},
                UserID => $Self->{Authorization}->{UserID},
            );
            $FAQArticle{Rating}    = $VoteDataHashRef->{Result};
            $FAQArticle{VoteCount} = $VoteDataHashRef->{Votes};
        }

        $Self->_FilterFAQArticleFields(
            FAQArticle => \%FAQArticle
        );

        # add
        push(@FAQArticleData, \%FAQArticle);
    }

    if ( scalar(@FAQArticleData) == 1 ) {
        return $Self->_Success(
            FAQArticle => $FAQArticleData[0],
        );
    }

    # return result
    return $Self->_Success(
        FAQArticle => \@FAQArticleData,
    );
}


sub _GetDynamicFields {
    my ( $Self, %Param ) = @_;

    my @DynamicFields;

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    # get all dynamic fields for the object type Ticket
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'FAQArticle'
    );

    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {

        # validate each dynamic field
        next DYNAMICFIELD if !$DynamicFieldConfig;
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

        # ignore DFs which are not visible for the customer, if the user session is a Customer session
        next DYNAMICFIELD if $Self->{Authorization}->{UserType} eq 'Customer' && !$DynamicFieldConfig->{CustomerVisible};

        # get the current value for each dynamic field
        my $Value = $DynamicFieldBackendObject->ValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $Param{FAQArticleID},
        );

        if ($Value) {
            my $PreparedValue = $Self->_GetPrepareDynamicFieldValue(
                Config          => $DynamicFieldConfig,
                Value           => $Value,
                NoDisplayValues => [ split(',', $Param{Data}->{NoDynamicFieldDisplayValues}||'') ]
            );

            if (IsHashRefWithData($PreparedValue)) {
                push(@DynamicFields, $PreparedValue);
            }
        }
    }

    return \@DynamicFields;
}

sub _FilterFAQArticleFields {
    my ( $Self, %Param ) = @_;

    my $IsCustomer = $Self->{Authorization}->{UserType} eq 'Customer';

    return if !$IsCustomer;

    for my $Field (qw(Field1 Field2 Field3 Field4 Field5 Field6)) {
        my $FieldConfig = $Kernel::OM->Get('Config')->Get('FAQ::Item::' . $Field) || {};

        if ( $FieldConfig && $FieldConfig->{'Show'} eq 'internal') {
            delete $Param{FAQArticle}->{$Field};
        }
    }
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
