# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::Helper::Object;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Log',
    'Automation',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub GetType {
    my ( $Self, %Param ) = @_;

    return $Self->{Type};
}

sub SetType {
    my ( $Self, $Type ) = @_;

    $Self->{Type} = $Type;

    $Self->{Object} = $Self->AsObject();
}

sub SetDefinition {
    my ( $Self, $Definition ) = @_;

    $Self->{Definition} = $Definition;

    $Self->{Object} = $Self->AsObject();
}

sub AsObject {
    my ( $Self, %Param ) = @_;
    my $Object;
    my $Success;
    my $LogMessage;

    return if !$Self->{Type} || !$Self->{Definition};

    if ( $Self->{Type} eq 'YAML') {
        $Success = $Object = $Kernel::OM->Get('YAML')->Load(
            Data => $Self->{Definition}
        );
        if ( !$Success ) {
            # the relevant error message is the 3rd last
            $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
                Type  => 'error',
                What  => 'Message',
                Index => -3,
            );
        }
    }
    elsif ( $Self->{Type} eq 'JSON') {
        $Success = $Object = $Kernel::OM->Get('JSON')->Decode(
            Data => $Self->{Definition}
        );
        if ( !$Success ) {
            $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
                Type => 'error',
                What => 'Message',
            );
        }
    }

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Unable to assemble object! ($LogMessage)",
            UserID   => 1
        );
    }

    return $Object;
}

sub AsString {
    my ( $Self, %Param ) = @_;

    return $Self->{Definition}
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
