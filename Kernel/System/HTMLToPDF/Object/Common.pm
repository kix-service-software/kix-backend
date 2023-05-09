# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
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

sub GetPossibleExpands {
    my ( $Self, %Param) = @_;

    return [];
}

sub _GetDynamicFields {
    my ( $Self, %Param ) = @_;

    return 1 if !$Param{Expands};
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

sub _Filter {
    my ($Self, %Param) = @_;

    my $Match = 0;

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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut