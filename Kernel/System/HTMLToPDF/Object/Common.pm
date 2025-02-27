# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Object::Common;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::HTMLToPDF::Common - print management

=head1 SYNOPSIS

All print functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    my $Params = $Self->GetParams();
    for my $Key ( keys %{$Params} ) {
        $Self->{$Key} = $Params->{$Key};
    }

    return $Self;
}

=item GetParams()

return a arrayref of possible expands of the object

    my $Arrayref = $BackendObject->GetPossibleExpands();

    $Arrayref = [
        'DynamicField',
        'Article',
        ...
    ]

=cut
sub GetParams {
    my ( $Self, %Param) = @_;

    return {};
}

=item CheckParams()

checks the needed parameters of the object and returns success or an error message

    my $Result = $BackendObject->CheckParams(
        some parameters
    );

    returns 1 on success

    returns hashref with message on error

    $Result = {
        error => 'some message'
    }

=cut
sub CheckParams {
    my ( $Self, %Param) = @_;

    return 1;
}

=item DataGet()

returns an hashref with the datas of the object

    my $Hashref = $BackendObject->DataGet(
        Expands      => [], # optional, adds some related data to the object
        Filters      => {}, # optional, filtering the data of the object and returns only matched ones
        Data         => {}, # optional, overwrites the object data with the supplied
        ObjectID     => 1,  # required, the key is replaced for each object by e.g. TicketID. Is required to get the object data. Either ObjectNumber or ObjectID is required.
        ObjectNumber => 123 # required, the key is replaced for each object by e.g. TicketNumber. Is required to get the object data. Either ObjectNumber or ObjectID is required.
    );

    $Hashref = {
        ...
    }

=cut
sub DataGet {
    my ($Self, %Param) = @_;

    return {}
}

=item GetPossibleExpands()

return a arrayref of possible expands of the object

    my $Arrayref = $BackendObject->GetPossibleExpands();

    $Arrayref = [
        'DynamicField',
        'Article',
        ...
    ]

=cut
sub GetPossibleExpands {
    my ( $Self, %Param) = @_;

    return [];
}

=item ReplaceableLabel()

returns a hash ref of replaceable keys, only works for SubType "KeyValue" of block type "Table"

    my $Hashref = $BackendObject->ReplaceableLabel();

    $Hashref = {
        'Key' => 'Replacement',
        ...
    }

=cut
sub ReplaceableLabel {
    my ( $Self, %Param ) = @_;

    return {};
}

=item _GetDynamicFields()

prepared values of the expand type 'DynamicField' of the object and add it to the given data

    my $AttachmentDirID = $BackendObject->_GetDynamicFields(
        ObjectID => 123,      # required
        UserID   => 123       # required
        Type     => 'Ticket', # required
        Data     => {...}     # required
    );

=cut
sub _GetDynamicFields {
    my ( $Self, %Param ) = @_;

    for my $Needed (
        qw(
            ObjectID UserID Type Data
        )
    ) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    return 1 if IsHashRefWithData($Param{Data}->{Expands}->{DynamicField});

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    my $Type = $Param{Type};
    my $ID   = $Param{ObjectID};

    # get all dynamic fields for the object type xyz
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => $Type,
        UserID     => $Param{UserID}
    );

    for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {

        # validate each dynamic field
        next if !$DynamicFieldConfig;
        next if !IsHashRefWithData($DynamicFieldConfig);
        next if !$DynamicFieldConfig->{Name};

        # get the current value for each dynamic field
        my $Value = $DynamicFieldBackendObject->ValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $ID,
        );

        # get the current value for each dynamic field
        my $Result = $DynamicFieldBackendObject->HTMLDisplayValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Value,
        );

        # set the dynamic field name and value into the data hash
        $Param{Data}->{Expands}->{DynamicField}->{ "DynamicField_$DynamicFieldConfig->{Name}" } = {
            %{$DynamicFieldConfig},
            Value => $Result->{Value}
        };
    }
    return 1;
}

=item _Filter()

checks if the given data matches with the filter

    return 0|1;

=cut
sub _Filter {
    my ($Self, %Param) = @_;

    for my $Needed (
        qw(
            Data Filter
        )
    ) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $Match = 0;

    return $Match if !IsHashRefWithData($Param{Filter});

    OPERATOR:
    for my $Operator ( sort keys %{$Param{Filter}} ) {
        if ( $Operator eq 'AND' ) {
            $Match = $Self->_FilterAND (
                Filters => $Param{Filter}->{$Operator},
                Data    => $Param{Data}
            );
        }
        else {
            $Match = $Self->_FilterOR (
                Filters => $Param{Filter}->{$Operator},
                Data    => $Param{Data}
            );
        }
    }

    return $Match;
}

=item _FilterAND()

checks if the given data matches with the filter as AND condition

    return 0|1;

=cut
sub _FilterAND {
    my ($Self, %Param) = @_;

    my $Data    = $Param{Data};
    my @Filters = @{$Param{Filters}};

    FILTERS:
    for my $Filter ( @Filters ) {
        my @Values;
        my $Field = $Filter->{Field};

        if ( ref $Filter->{Value} eq 'ARRAY' ) {
            @Values = @{$Filter->{Value}};
        }
        else {
            push( @Values, $Filter->{Value});
        }

        next FILTERS if ( !defined $Data->{$Field});
        for my $Value ( @Values ) {
            if ( $Filter->{Type} eq 'CONTAINS' ) {
                if ( ref $Data->{$Field} eq 'ARRAY' ) {
                    for my $DataVal ( @{$Data->{$Field}} ) {
                        next FILTERS if ( $DataVal =~ /$Value/sxm );
                    }
                    return 0;
                }
                else {
                    return 0 if ( $Data->{$Field} !~ /$Value/sxm );
                }
            }

            if ( $Filter->{Type} eq 'EQ' ) {
                if ( ref $Data->{$Field} eq 'ARRAY' ) {
                    for my $DataVal ( @{$Data->{$Field}} ) {
                        next FILTERS if ( $DataVal eq $Value );
                    }
                    return 0;
                }
                else {
                    return 0 if ( $Data->{$Field} ne $Value );
                }
            }
        }
    }
    return 1;
}

=item _FilterOR()


checks if the given data matches with the filter as OR condition

    return 0|1;

=cut
sub _FilterOR {
    my ($Self, %Param) = @_;

    my $Data    = $Param{Data};
    my @Filters = @{$Param{Filters}};

    FILTERS:
    for my $Filter ( @Filters ) {
        my @Values;

        if ( ref $Filter->{Value} eq 'ARRAY' ) {
            @Values = @{$Filter->{Value}};
        }
        else {
            push( @Values, $Filter->{Value});
        }

        next FILTERS if ( !defined $Data->{$Filter->{Field}});
        for my $Value ( @Values ) {
            if ( $Filter->{Type} eq 'CONTAINS' ) {
                if ( ref $Data->{$Filter->{Field}} eq 'ARRAY' ) {
                    for my $DataVal ( @{$Data->{$Filter->{Field}}} ) {
                        return 1 if ( $DataVal =~ /$Value/sxm );
                    }
                }
                else {
                    return 1 if ( $Data->{$Filter->{Field}} =~ /$Value/sxm );
                }
            }

            if ( $Filter->{Type} eq 'EQ' ) {
                if ( ref $Data->{$Filter->{Field}} eq 'ARRAY' ) {
                    for my $DataVal ( @{$Data->{$Filter->{Field}}} ) {
                        return 1 if ( $DataVal eq $Value );
                    }
                }
                else {
                    return 1 if ( $Data->{$Filter->{Field}} eq $Value );
                }
            }
        }
    }

    return 0;
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
