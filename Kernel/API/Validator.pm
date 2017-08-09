# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Validator;

use strict;
use warnings;

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
        $Self->{$Needed} = $Param{$Needed} || return {
            Success => 0,
            Summary => "Got no $Needed!",
        };
    }

    # init all validators
    my $ValidatorList = $Kernel::OM->Get('Kernel::Config')->Get('API::Validator::Module');
    
    foreach my $Validator (sort keys %{$ValildatorList}) {
        my $Backend = 'Kernel::API::Validator::' . $ValidatorList->{$Validator}->{Module};

        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($Backend) ) {
            return $Self->{DebuggerObject}->Error( Summary => "Validator $Backend not found." );
        }
        my $BackendObject = $Backend->new( %{$Self} );

        # if the backend constructor failed, it returns an error hash, pass it on in this case
        return $BackendObject if ref $Self->{Validators}->{$Validator} ne $Backend;

        # register backend for each validated attribute
        foreach my $ValidatedAttribute ( sort split(/\s*,\s*/, $ValidatorList->{$Validator}->{Validates} ) {
            if ( !IsArrayRefWithData( $Self->{Validators}->{$ValidatedAttribute} ) ) {
                $Self->{Validators}->{$ValidatedAttribute} = [];
            }
            push @{$Self->{Validators}->{$ValidatedAttribute}}, $Backend;
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
    }

    # if no Data is given to validate, then return successful
    if ( !IsHashRefWithData($Param{Data}) ) {
        return {
            Success => 1,
        }
    }

    # validate attributes
    ATTRIBUTE:
    foreach my $Attribute ( sort keys %{$Param{Data}} ) {
        # execute validator if one exists for this attribute
        if ( (IsArrayRefWithData{$Self->{Validators}->{$Attribute}) ) {
            foreach $Validator ( @{$Self->{Validators}->{$Attribute}} ) {
                my $ValidatorResult = $Validator->Validate(
                    Attribute => $Attribute,
                    Value     => $Param{Data}->{$Attribute},
                );

                if ( !IsHashRefWithData($ValidatorResult) || !$ValidatorResult->{Success} ) {
                    $Result = $ValidatorResult;
                    last ATTRIBUTE;
                }
            }
        }
    }

    return $Result;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
