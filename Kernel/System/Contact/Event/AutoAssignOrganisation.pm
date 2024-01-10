# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Contact::Event::AutoAssignOrganisation;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Contact
    Log
    Organisation
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
    for ( qw(Data Event Config) ) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    for ( qw(ID) ) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }
    return if (
        ref( $Param{Config}->{MappingMethods} ) ne 'ARRAY'
        || !@{ $Param{Config}->{MappingMethods} }
    );

    # check if contact exists and has no PrimaryOrganisationID
    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        ID     => $Param{Data}->{ID},
        Silent => 1,
    );
    return 1 if ( !%Contact );
    return 1 if $Contact{PrimaryOrganisationID};

    # process mapping methods
    METHOD:
    for my $MappingMethod ( @{ $Param{Config}->{MappingMethods} } ) {
        # check if method config is valid and active
        next METHOD if (
            ref( $MappingMethod ) ne 'HASH'
            || !$MappingMethod->{Active}
            || !$MappingMethod->{Method}
        );

        # prepare function name
        my $Function = '_' . $MappingMethod->{Method};

        # check for supported method
        next METHOD if ( !$Self->can( $Function ) );

        # process method
        my $Success = $Self->$Function(
            Contact => \%Contact,
            Config  => $MappingMethod,
        );

        # end processing, if organisation was set
        last METHOD if ( $Success ) ;
    }

    return 1;
}

sub _MailDomain {
    my ( $Self, %Param ) = @_;

    # get domain part of contact primary email
    my ($Name, $Domain) = split( /[@]/sm, $Param{Contact}->{Email});

    # prepare parts of domain
    my @Parts = split(/[.]/sm, $Domain);

    # prepare possible pattern
    my $Pattern = $Self->_GetMailDomainPattern(
        Parts => \@Parts,
        Count => 0
    );
    return if ( !IsArrayRefWithData( $Pattern ) );

    # search for relevant organisations
    my @OrganisationIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Organisation',
        Result     => 'ARRAY',
        Search     => {
            AND => [
                {
                    Operator => 'IN',
                    Field    => 'DynamicField_AddressDomainPattern',
                    Value    => $Pattern
                }
            ]
        },
        Sort => [
            {
                Field     => 'Number',
                Direction => 'ASCENDING'
            }
        ],
        UserID   => 1,
        UserType => 'Agent'
    );

    return if ( !@OrganisationIDs );

    # update contact with found organisations
    my $Success = $Kernel::OM->Get('Contact')->ContactUpdate(
        %{ $Param{Contact} },
        PrimaryOrganisationID => $OrganisationIDs[0],
        OrganisationIDs       => \@OrganisationIDs,
        UserID                => 1
    );
    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Could not update contact with method "MailDomain".'
        );
        return;
    }

    # confirm that organisation was set
    return 1;
}

sub _DefaultOrganisation {
    my ( $Self, %Param ) = @_;

    # check configuration
    my $DefaultOrganisation = $Param{Config}->{DefaultOrganisation};
    if ( !$DefaultOrganisation ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need "DefaultOrganisation" in method configuration'
        );
        return;
    }

    # check default organisation
    my $OrganisationID = $Self->_GetOrganisationID(
        Organisation => $DefaultOrganisation
    );
    return if ( !$OrganisationID );

    # update contact with default organisation
    my $Success = $Kernel::OM->Get('Contact')->ContactUpdate(
        %{ $Param{Contact} },
        PrimaryOrganisationID => $OrganisationID,
        UserID                => 1
    );
    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Could not update contact with method "DefaultOrganisation".'
        );
        return;
    }

    return 1;
}

sub _PersonalOrganisation {
    my ( $Self, %Param ) = @_;

    # create organisation based on contact email
    my $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
        Number  => $Param{Contact}->{Email},
        Name    => $Param{Contact}->{Email},
        ValidID => 1,
        UserID  => 1
    );
    if ( !$OrganisationID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Could not create organisation for method "PersonalOrganisation".'
        );
        return;
    }

    # update contact with personal organisation
    my $Success = $Kernel::OM->Get('Contact')->ContactUpdate(
        %{ $Param{Contact} },
        PrimaryOrganisationID => $OrganisationID,
        UserID                => 1
    );
    if ( !$Success ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Could not update contact with method "PersonalOrganisation".'
        );
    }

    return 1;
}

sub _GetMailDomainPattern {
    my ( $Self, %Param ) = @_;

    my @Pattern;
    my $Parts  = $Param{Parts};
    my $Count  = $Param{Count};

    return if !defined $Parts->[$Count];

    for ( 0 .. 1 ) {
        my $Part = ($_ == 0 ? q{*} : $Parts->[$Count]);

        my $Result = $Self->_GetMailDomainPattern(
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

sub _GetOrganisationID {
    my ( $Self, %Param ) = @_;

    # lookup organisation by number
    my $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
        Number => $Param{Organisation},
        Silent => 1,
    );
    return $OrganisationID if ( $OrganisationID );

    # lookup organisation by name
    $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
        Name   => $Param{Organisation},
        Silent => 1,
    );
    return $OrganisationID if ( $OrganisationID );

    # if given value is a number, check if it is a valid organisation id
    if ( $Param{Organisation} =~ m/^\d+$/ ) {
        my $Number = $Kernel::OM->Get('Organisation')->OrganisationLookup(
            ID     => $Param{Organisation},
            Silent => 1,
        );
        return $Param{Organisation} if ( $Number );
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


