# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Validator;

use strict;
use warnings;

use base qw(
    Kernel::API::Common
);

use Kernel::System::VariableCheck qw(:all);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Validator - API data validation interface

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object.

    use Kernel::API::Validator;

    my $ValidatorObject = Kernel::API::Validator->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # init all validators
    my $ValidatorList = $Kernel::OM->Get('Config')->Get('API::Validator::Module');

    foreach my $Validator (sort keys %{$ValidatorList}) {
        if ( $ValidatorList->{$Validator}->{ConsiderOperationRegEx} && $Param{Operation} !~ /$ValidatorList->{$Validator}->{ConsiderOperationRegEx}/ ) {
            # next validator if this one doesn't consider our current operation
            next;
        }
        elsif ( $ValidatorList->{$Validator}->{IgnoreOperationRegEx} && $Param{Operation} =~ /$ValidatorList->{$Validator}->{IgnoreOperationRegEx}/ ) {
            # next validator if this one ignores our current operation
            next;
        }

        if ( !$Kernel::OM->Get('Main')->Require($ValidatorList->{$Validator}->{Module}) ) {
            return $Self->_Error(
                Code    => 'Validator.InternalError',
                Message => "Validator $ValidatorList->{$Validator}->{Module} not found."
            );
        }
        my $BackendObject = $ValidatorList->{$Validator}->{Module}->new( %{$Self} );

        # if the backend constructor failed, it returns an error hash, pass it on in this case
        if ( ref $BackendObject ne $ValidatorList->{$Validator}->{Module} ) {
            return $BackendObject;
        }

        # register backend for each validated attribute
        foreach my $ValidatedAttribute ( sort split(/\s*,\s*/, $ValidatorList->{$Validator}->{Validates}) ) {
            if ( !IsArrayRefWithData( $Self->{Validators}->{$ValidatedAttribute} ) ) {
                $Self->{Validators}->{$ValidatedAttribute} = [];
            }
            push @{$Self->{Validators}->{$ValidatedAttribute}}, $BackendObject;
        }
    }

    return $Self;
}

=item Validate()

validate given data hash using registered validator modules

    my $Result = $ValidatorObject->Validate(
        ParentAttribute => '...',       # optional
        Data => {
            ...
        }
    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
    };

=cut

sub Validate {
    my ( $Self, %Param ) = @_;
    my $Result = {
        Success => 1,
    };

    # if no Data is given to validate, then return successful
    if ( !IsHashRefWithData($Param{Data}) ) {
        return $Self->_Success();
    }

    # validate attributes
    ATTRIBUTE:
    foreach my $Attribute ( sort keys %{$Param{Data}} ) {

        # ignore given but null values - we don't need to validate those
        next if !defined $Param{Data}->{$Attribute};

        # ignore placeholder values
        next if $Param{Data}->{$Attribute} =~ m/^<KIX_.+>$/;
        if ($Param{Data}->{$Attribute} =~ m/^0$|^[1-9]\d{1,19}$/ ) {
            $Param{Data}->{$Attribute} = 0 + $Param{Data}->{$Attribute};
        }

        # execute validator if one exists for this attribute
        if ( IsArrayRefWithData($Self->{Validators}->{$Attribute}) ) {
            $Result = $Self->_ValidateAttribute(
                ParentAttribute  => $Param{ParentAttribute},
                Attribute        => $Attribute,
                Data             => $Param{Data},
            );
            if ( !IsHashRefWithData($Result) || !$Result->{Success} ) {
                last ATTRIBUTE;
            }
        }
        else {
            # we don't have a valdator for this attribute itself, just traverse if necessary
            if ( IsArrayRefWithData($Param{Data}->{$Attribute}) ) {
                foreach my $Item ( @{$Param{Data}->{$Attribute}} ) {
                    my $ValidationResult = $Self->Validate(
                        ParentAttribute  => $Attribute,
                        Data             => $Item,
                    );
                    if ( !IsHashRefWithData($ValidationResult) || !$ValidationResult->{Success} ) {
                        $Result = $ValidationResult;
                        last ATTRIBUTE;
                    }
                }
            }
            elsif ( IsHashRefWithData($Param{Data}->{$Attribute}) ) {
                my $ValidationResult = $Self->Validate(
                    ParentAttribute  => $Attribute,
                    Data             => $Param{Data}->{$Attribute},
                );
                if ( !IsHashRefWithData($ValidationResult) || !$ValidationResult->{Success} ) {
                    $Result = $ValidationResult;
                    last ATTRIBUTE;
                }
            }
        }
    }

    return $Result;
}

sub _ValidateAttribute {
    my ( $Self, %Param ) = @_;
    my $Result = {
        Success => 1,
    };

    my @Values = IsArrayRef($Param{Data}->{$Param{Attribute}}) ? @{$Param{Data}->{$Param{Attribute}}} : ( $Param{Data}->{$Param{Attribute}} );

    VALIDATOR:
    foreach my $Validator ( @{$Self->{Validators}->{$Param{Attribute}}} ) {
        foreach my $Value ( @Values ) {
            my $ValidatorResult = $Validator->Validate(
                Attribute => $Param{Attribute},
                Data      => {
                    $Param{Attribute} => $Value
                }
            );

            if ( !IsHashRefWithData($ValidatorResult) || !$ValidatorResult->{Success} ) {
                $Result = $ValidatorResult;
                last VALIDATOR;
            }
        }
    }

    return $Result;
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
