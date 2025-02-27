# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::Job::Contact;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::Job::Common);

our @ObjectDependencies = qw(
    Config
    Cache
    DB
    Log
    User
    Valid
    ObjectSearch
);

=head1 NAME

Kernel::System::Automation::Job::Contact - job type for automation lib

=head1 SYNOPSIS

Handles contact based jobs.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

Run this job module. Returns the list of ContactIDs to run this job on.

Example:
    my @ContactIDs = $Object->Run(
        Filter => {}         # optional, filter for objects
        Data   => {},        # optional, contains the relevant data given by an event or otherwise
        UserID => 123,
    );

=cut

sub _Run {
    my ( $Self, %Param ) = @_;

    my $Filters = $Param{Filter};

    if (
        IsHashRefWithData($Param{Data})
        && (
            $Param{Data}->{ID}
            || $Param{Data}->{ContactID}
        )
    ) {
        # add ContactID to filter
        $Filters = $Self->_ExtendFilter(
            Filters => $Filters,
            Extend  => {
                Field    => 'ID',
                Operator => 'EQ',
                Value    => $Param{Data}->{ID} || $Param{Data}->{ContactID}
            }
        );
    }

    my @ContactListResult;
    if ( IsArrayRefWithData($Filters) ) {
        for my $Filter ( @{$Filters} ) {
            next if ( !IsHashRefWithData($Filter) );
            my @ContactIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                Search     => $Filter,
                ObjectType => 'Contact',
                Result     => 'ARRAY',
                UserID     => $Param{UserID}    || 1,
                UserType   => $Param{UserType} || 'Agent'
            );

            next if !@ContactIDs || !scalar(@ContactIDs);

            push(@ContactListResult, @ContactIDs);

        }
        @ContactListResult = $Kernel::OM->Get('Main')->GetUnique(@ContactListResult);
    } else {

        # get full contact list
        my %ContactList = $Kernel::OM->Get('Contact')->ContactList(
            Valid => 0
        );
        @ContactListResult = %ContactList ? @{[keys %ContactList]} : ();
    }

    return @ContactListResult;
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
