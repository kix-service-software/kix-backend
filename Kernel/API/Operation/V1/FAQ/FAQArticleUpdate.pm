# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleUpdate - API FAQArticle Create Operation backend

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
            Required => 1
        },
        'FAQArticle::CustomerVisible' => {
            RequiresValueIfUsed => 1,
            OneOf => [
                0,
                1
            ]
        },
    }
}

=item Run()

perform FAQArticleUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            FAQArticleID => 123,
            FAQArticle  => {
                Title           => 'Some Text',
                CategoryID      => 1,
                ValidID         => 1,
                CustomerVisible => 1,                # optional, 1|0, default 0
                LanguageID      => 'en',             # optional
                ContentType     => 'text/plain',     # optional, or 'text/plain'
                Number          => '13402',          # optional
                Keywords        => [                 # optional
                    'some', 'keywords',
                ],
                Field1      => 'Problem...',
                Field2      => 'Solution...',
                Field3      => '...',
                Field4      => '...',
                Field5      => '...',
                Field6      => '...',
                UserID      => 1,
                Approved    => 1,
                ApprovalOff => 1,               # optional, (if set to 1 approval is ignored. This is
                                                #   important when called from FAQInlineAttachmentURLUpdate)
                DynamicFields => [                  # optional
                    {
                        Name   => 'some name',
                        Value  => $Value,           # value type depends on the dynamic field
                    },
                    # ...
                ],
            },
        },
    );

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            FAQArticleID  => 123,              # ID of the updated FAQArticle
        },
    };

=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # check if FAQArticle exists
    my %FAQArticleData = $Kernel::OM->Get('FAQ')->FAQGet(
        ItemID     => $Param{Data}->{FAQArticleID},
        ItemFields => 1,
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !%FAQArticleData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # isolate and trim FAQArticle parameter
    my $IncomingFAQArticle = $Self->_Trim(
        Data => $Param{Data}->{FAQArticle}
    );

    # check dynamic fields
    if ( IsArrayRefWithData( $IncomingFAQArticle->{DynamicFields} ) ) {

        # check DynamicField internal structure
        foreach my $DynamicFieldItem (@{$IncomingFAQArticle->{DynamicFields}}) {
            if ( !IsHashRefWithData($DynamicFieldItem) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter FAQArticle::DynamicFields is invalid!",
                );
            }

            # check DynamicField attribute values
            my $DynamicFieldCheck = $Self->_CheckDynamicField(
                DynamicField => $DynamicFieldItem,
                ObjectType   => 'FAQArticle'
            );

            if ( !$DynamicFieldCheck->{Success} ) {
                return $Self->_Error(
                    %{$DynamicFieldCheck}
                );
            }
        }
    }

    # merge attributes
    my %FAQArticle;
    foreach my $Key ( qw(Name StateID CategoryID Language Approved ContentType Title Field1 Field2 Field3 Field4 Field5 Field6 ApprovalOff ValidID) ) {
       $FAQArticle{$Key} = exists $IncomingFAQArticle->{$Key} ? $IncomingFAQArticle->{$Key} : $FAQArticleData{$Key};
    }

    if (exists $IncomingFAQArticle->{CustomerVisible}) {
        $FAQArticle{Visibility} = $IncomingFAQArticle->{CustomerVisible} ? 'external' : 'internal';
    } else {
        $FAQArticle{Visibility} = $FAQArticleData{Visibility};
    }

    # add keywords
    $FAQArticle{Keywords} = IsArrayRefWithData($IncomingFAQArticle->{Keywords}) ? join(' ', @{$IncomingFAQArticle->{Keywords}}) : $FAQArticleData{Keywords};

    # update FAQArticle
    my $Success = $Kernel::OM->Get('FAQ')->FAQUpdate(
        ItemID      => $Param{Data}->{FAQArticleID},
        %FAQArticle,
        UserID      => $Self->{Authorization}->{UserID}
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # set dynamic fields
    if ( IsArrayRefWithData( $IncomingFAQArticle->{DynamicFields} ) ) {

        DYNAMICFIELD:
        foreach my $DynamicField ( @{ $IncomingFAQArticle->{DynamicFields} } ) {
            my $Result = $Self->_SetDynamicFieldValue(
                %{$DynamicField},
                ObjectID   => $Param{Data}->{FAQArticleID},
                ObjectType => 'FAQArticle',
                UserID     => $Self->{Authorization}->{UserID},
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    Code    => 'Operation.InternalError',
                    Message => "Dynamic Field $DynamicField->{Name} could not be set ($Result->{Message})",
                );
            }
        }
    }

    # return result
    return $Self->_Success(
        FAQArticleID => $Param{Data}->{FAQArticleID},
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
