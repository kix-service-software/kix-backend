# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
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

    return if !$Self->{Type} || !$Self->{Definition};

    if ( $Self->{Type} eq 'YAML') {
        $Object = $Kernel::OM->Get('YAML')->Load(
            Data => $Self->{Definition}
        );
    }
    elsif ( $Self->{Type} eq 'JSON') {
        $Object = $Kernel::OM->Get('JSON')->Decode(
            Data => $Self->{Definition}
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
