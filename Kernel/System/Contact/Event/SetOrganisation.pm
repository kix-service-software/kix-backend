# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Contact::Event::SetOrganisation;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Config
    Log
    Contact
    DB
);

use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config)) {
        if ( !$Param{$_} ) {
            return if $Param{Silent};
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    for (qw(ID)) {
        if ( !$Param{Data}->{$_} ) {
            return if $Param{Silent};
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }

    my $Config = $Kernel::OM->Get('Config')->Get('Contact::Organisation::Methode');

    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        ID => $Param{Data}->{ID}
    );

    return 1 if $Contact{PrimaryOrganisationID};

    for my $Method (
        qw(
            MailDomain Default Personal
        )
    ) {
        my $Function = "_$Method";
        my $Success = $Self->$Function(
            Config  => $Config,
            Contact => \%Contact
        );

        last if ( $Success ) ;
    }

    return 1;
}

sub _MailDomain {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Config}->{MailDomain};
    return if !$Param{Config}->{MailDomain};

    my ($Name, $Domain) = split( /[@]/sm, $Param{Contact}->{Email});
    my @Parts = split(/[.]/sm, $Domain);

    my $Pattern = $Self->_GetPattern(
        Parts => \@Parts,
        Count => 0
    );

    return if ( !IsArrayRefWithData($Pattern) );

    # Todo: Use the new search function (ObjectSearch) to search for organisations
    my %Organisations = $Kernel::OM->Get('Organisation')->OrganisationSearch(
        DynamicField => {
            Operator => 'EQ',
            Field    => 'AddressDomainPattern',
            Value    => $Pattern
        }
    );

    return if ( !%Organisations );

    my @OrganisationIDs  = sort keys %Organisations;

    my $Success = $Kernel::OM->Get('Contact')->ContactUpdate(
        %{$Param{Contact}},
        PrimaryOrganisationID => $OrganisationIDs[0],
        OrganisationIDs       => \@OrganisationIDs,
        UserID                => 1
    );

    if ( !$Success ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Event::SetOrganisation: could not update contact with method "MailDomain".'
        );
        return;
    }

    return 1;
}

sub _Default {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Config}->{Default};
    return if !$Param{Config}->{Default};

    my $Default = $Kernel::OM->Get('Config')->Get('Contact::Organisation::Default');

    if ( !$Default ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Event::SetOrganisation: Need configuration "Contact::Organisation::Default"'
        );
        return;
    }

    my $OrganisationID = $Self->_CheckDefault(
        Default => $Default
    );

    return if ( !$OrganisationID );

    my $Success = $Kernel::OM->Get('Contact')->ContactUpdate(
        %{$Param{Contact}},
        PrimaryOrganisationID => $OrganisationID,
        UserID                => 1
    );

    if ( !$Success ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Event::SetOrganisation: could not update contact with method "Default".'
        );
        return;
    }

    return 1;
}

sub _Personal {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Config}->{Personal};
    return if !$Param{Config}->{Personal};

    my $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
        Number  => $Param{Contact}->{Email},
        Name    => $Param{Contact}->{Email},
        ValidID => 1,
        UserID  => 1
    );

    if ( !$OrganisationID ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Event::SetOrganisation: could not set organisation for contact with method "Personal".'
        );
        return;
    }

    my $Success = $Kernel::OM->Get('Contact')->ContactUpdate(
        %{$Param{Contact}},
        PrimaryOrganisationID => $OrganisationID,
        UserID                => 1
    );

    if ( !$Success ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Event::SetOrganisation: could not update contact with method "Personal".'
        );
    }

    return 1;
}

sub _GetPattern {
    my ( $Self, %Param ) = @_;

    my @Pattern;
    my $Parts  = $Param{Parts};
    my $Count  = $Param{Count};

    return if !defined $Parts->[$Count];

    for ( 0 .. 1 ) {
        my $Part = ($_ == 0 ? q{*} : $Parts->[$Count]);

        my $Result = $Self->_GetPattern(
            Parts  => $Parts,
            Count  => $Count+1
        );

        if ( IsArrayRefWithData($Result) ) {
            my %Data = map { $Part . q{.} . $_ => 1 } @{$Result};
            push(@Pattern, keys %Data);
        }
        else {
            push(@Pattern, $Part);
        }
    }

    return \@Pattern;
}

sub _CheckDefault {
    my ( $Self, %Param ) = @_;

    my $ID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
        Number => $Param{Default},
        Silent => 1,
    );

    if ( !$ID ) {
        $ID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
            Name   => $Param{Default},
            Silent => 1,
        );
    }

    if (
        !$ID
        && $Param{Default} =~ /^\d+$/sm
    ) {
        my $Number = $Kernel::OM->Get('Organisation')->OrganisationLookup(
            ID     => 1,
            Silent => 1,
        );

        return if !$Number;
        $ID = $Param{Default};
    }

    return $ID;
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
