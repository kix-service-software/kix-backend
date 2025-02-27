# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::Number::ClassPrefixes;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ITSMConfigItem::Number::ClassPrefixes - config item number backend module

=head1 SYNOPSIS

All class prefixes config item number functions

=over 4

=cut

=item ConfigItemNumberCreate()

create a new config item number

    my $Number = $ConfigItemObject->ConfigItemNumberCreate(
        ClassID => 123,
    );

=cut

sub ConfigItemNumberCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(ClassID) ) {
        if ( !$Param{ $Needed } ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!",
                );
            }
            return;
        }
    }

    # get config for number generator module
    my $NumberGeneratorConfig = $Kernel::OM->Get('Config')->Get('ITSMConfigItem::Number::ClassPrefixes') || {};

    # get class name
    my $ItemDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
        ItemID        => $Param{ClassID},
        NoPreferences => 1,
    );
    if (
        !IsHashRefWithData( $ItemDataRef )
        || $ItemDataRef->{Class} ne 'ITSM::ConfigItem::Class'
        || !IsStringWithData( $ItemDataRef->{Name} )
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid ClassID!',
            );
        }
        return;
    }
    my $Class = $ItemDataRef->{Name};

    # prepare Prefix, remove leading and trailing whitespaces
    my $Prefix;
    # use class specific prefix if defined and not empty
    if(
        IsHashRefWithData( $NumberGeneratorConfig->{Prefixes} )
        && IsStringWithData( $NumberGeneratorConfig->{Prefixes}->{ $Class } )
    ) {
        $Prefix = $NumberGeneratorConfig->{Prefixes}->{ $Class };
    }
    # use DefaultPrefix if defined and not empty
    elsif ( IsStringWithData( $NumberGeneratorConfig->{DefaultPrefix} ) ) {
        $Prefix = $NumberGeneratorConfig->{DefaultPrefix};
    }
    # fallback to class id
    else {
        $Prefix = $Param{ClassID};
    }
    $Prefix =~ s/^\s|\s$//;

    # prepare Separator, remove leading and trailing whitespaces
    my $Separator = $NumberGeneratorConfig->{Separator} // '';
    $Separator    =~ s/^\s|\s$//;

    # prepare Counter Length, fallback to 4
    my $CounterLength = $NumberGeneratorConfig->{CounterLength};
    if ( !IsPositiveInteger( $CounterLength ) ) {
        $CounterLength = 4;
    }

    # prepare SystemID with Separator when configured
    my $SystemID = '';
    if ( $NumberGeneratorConfig->{IncludeSystemID} ) {
        $SystemID = $Kernel::OM->Get('Config')->Get('SystemID') . $Separator;
    }

    # get current counter
    my $CurrentCounter = $Self->ConfigItemCounterGet(
        ClassID => $Param{ClassID},
        Counter => 'AutoIncrement',
        Silent  => $Param{Silent},
    ) || 0;

    CIPHER:
    for my $Cipher ( 1 .. 1_000_000_000 ) {
        # prepare new number
        my $Number = sprintf( '%s%s%s%0' . $CounterLength . 'd', $Prefix, $Separator, $SystemID, ( $CurrentCounter + $Cipher ) );

        # check for existing number
        my $Duplicate = $Self->ConfigItemLookup(
            ConfigItemNumber => $Number,
        );
        next CIPHER if ( $Duplicate );

        # set new counter
        $Self->ConfigItemCounterSet(
            ClassID => $Param{ClassID},
            Counter => 'AutoIncrement',
            Value   => ( $CurrentCounter + $Cipher ),
            Silent  => $Param{Silent},
        );

        return $Number;
    }

    return;
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
