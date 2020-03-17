# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
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

    use Kernel::API::Debugger;
    use Kernel::API::Validator;

    my $DebuggerObject = Kernel::API::Debugger->new(
        DebuggerConfig   => {
            DebugThreshold  => 'debug',
            TestMode        => 0,           # optional, in testing mode the data will not be written to the DB
            # ...
        },
        WebserviceID      => 12,
        CommunicationType => Requester, # Requester or Provider
        RemoteIP          => 192.168.1.1, # optional
    );
    my $ValidatorObject = Kernel::API::Validator->new(
        DebuggerObject => $DebuggerObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    for my $Needed (qw( DebuggerObject)) {
        $Self->{$Needed} = $Param{$Needed} || return $Self->_Error(
            Code    => 'Validator.InternalError',
            Message => "Got no $Needed!",
        );
    }

    # init all validators
    my $ValidatorList = $Kernel::OM->Get('Kernel::Config')->Get('API::Validator::Module');
    
    foreach my $Validator (sort keys %{$ValidatorList}) {
        if ( $ValidatorList->{$Validator}->{ConsiderOperationRegEx} && $Param{Operation} !~ /$ValidatorList->{$Validator}->{ConsiderOperationRegEx}/ ) {
            # next validator if this one doesn't consider our current operation
            next;
        }
        elsif ( $ValidatorList->{$Validator}->{IgnoreOperationRegEx} && $Param{Operation} =~ /$ValidatorList->{$Validator}->{IgnoreOperationRegEx}/ ) {
            # next validator if this one ignores our current operation
            next;
        }

        my $Backend = 'Kernel::API::Validator::' . $ValidatorList->{$Validator}->{Module};

        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($Backend) ) {
            return $Self->_Error( 
                Code    => 'Validator.InternalError',
                Message => "Validator $Backend not found." 
            );
        }
        my $BackendObject = $Backend->new( %{$Self} );

        # if the backend constructor failed, it returns an error hash, pass it on in this case
        if ( ref $BackendObject ne $Backend ) {
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

        # execute validator if one exists for this attribute
        if ( IsArrayRefWithData($Self->{Validators}->{$Attribute}) ) {
            $Result = $Self->_ValidateAttribute(
                Attribute => $Attribute,
                Data      => $Param{Data},
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
                        Data => $Item,
                    );
                    if ( !IsHashRefWithData($ValidationResult) || !$ValidationResult->{Success} ) {
                        $Result = $ValidationResult;
                        last ATTRIBUTE;
                    }
                }
            }
            elsif ( IsHashRefWithData($Param{Data}->{$Attribute}) ) {
                my $ValidationResult = $Self->Validate(
                    Data => $Param{Data}->{$Attribute},
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

    VALIDATOR:
    foreach my $Validator ( @{$Self->{Validators}->{$Param{Attribute}}} ) {
        my $ValidatorResult = $Validator->Validate(
            Attribute => $Param{Attribute},
            Data      => $Param{Data},
        );

        if ( !IsHashRefWithData($ValidatorResult) || !$ValidatorResult->{Success} ) {
            $Result = $ValidatorResult;
            last VALIDATOR;
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
