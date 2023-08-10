# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::Job::Contact;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::Job::Common);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
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

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    my $Filter =  $Param{Filter};

    if ( IsHashRefWithData($Param{Data}) && ($Param{Data}->{ID} || $Param{Data}->{ContactID}) ) {
        # add ContactID to filter
         $Filter //= {};
         $Filter->{AND} //= [];
         push @{$Filter->{AND}}, {
             Field    => 'ID',
             Operator => 'EQ',
             Value    => $Param{Data}->{ID} || $Param{Data}->{ContactID}
         };
    }

    my @ContactIDs;

    if ( IsHashRefWithData($Filter) ) {
        # do first OR to prevent replacement of prior AND search with empty result
        my %SearchParams;
        SEARCHTYPE:
        foreach my $SearchType ( qw(OR AND) ) {
            next SEARCHTYPE if ( !IsArrayRefWithData($Filter->{$SearchType}) );
            my @SearchTypeResult;
            foreach my $SearchItem ( @{ $Filter->{$SearchType} } ) {

                my $Value = $SearchItem->{Value};

                if ( $SearchItem->{Operator} eq 'CONTAINS' ) {
                    $Value = '*' . $Value . '*';
                } elsif ( $SearchItem->{Operator} eq 'STARTSWITH' ) {
                    $Value = $Value . '*';
                } elsif ( $SearchItem->{Operator} eq 'ENDSWITH' ) {
                    $Value = '*' . $Value;
                } elsif ( $SearchItem->{Operator} eq 'LIKE' ) {
                    $Value .= '*';
                    # just prefix needed as config, because some DB do not use indices with leading wildcard - performance!
                    if( $Kernel::OM->Get('Config')->Get('ContactSearch::UseWildcardPrefix') ) {
                        $Value = '*' . $Value;
                    }
                }

                if ( $SearchItem->{Field} =~ /^(Login|UserLogin)$/ ) {
                    if ( $SearchItem->{Operator} eq 'EQ' ) {
                        $SearchParams{LoginEquals} = $Value;
                    } else {
                        $SearchParams{Login} = $Value;
                    }
                } elsif ( $SearchItem->{Field} =~ /^(ID|AssignedUserID|UserID|OrganisationIDs|Title|Firstname|Lastname|City|Country|Fax|Mobil|Phone|Street|Zip|ValidID)$/ ) {
                    $SearchParams{$SearchItem->{Field}} = $Value;
                } elsif ( $SearchItem->{Field} eq 'Email' ) {
                    if ($SearchItem->{Operator} eq 'EQ') {
                        $SearchParams{EmailEquals} = $Value;
                    } elsif ($SearchItem->{Operator} eq 'IN') {
                        $SearchParams{EmailIn} = $Value;
                    } else {
                        $SearchParams{Email} = $Value;
                    }
                } elsif ( $SearchItem->{Field} eq 'PrimaryOrganisationID' ) {
                    $SearchParams{OrganisationID} = $Value;
                } elsif ($SearchItem->{Field} =~ /^DynamicField_/smx ) {
                    $SearchParams{DynamicField} = {
                        Field    => $SearchItem->{Field},
                        Operator => $SearchItem->{Operator},
                        Value    => $Value
                    };
                } else {
                    $SearchParams{Search} = $Value;
                }

                # merge results
                if ( $SearchType eq 'OR' ) {
                    my %SearchResult = $Kernel::OM->Get('Contact')->ContactSearch(
                        %SearchParams,
                        Valid => 0,
                    );

                    @SearchTypeResult = $Kernel::OM->Get('Main')->GetCombinedList(
                        ListA => \@SearchTypeResult,
                        ListB => [ keys %SearchResult ],
                        Union => 1
                    );

                    # reset
                    %SearchParams = ();
                }
            }
            if ( $SearchType eq 'AND' ) {
                my %SearchResult = $Kernel::OM->Get('Contact')->ContactSearch(
                    %SearchParams,
                    Valid => 0,
                );
                @SearchTypeResult = %SearchResult ? @{[keys %SearchResult]} : ();
            }

            if ( !@ContactIDs ) {
                @ContactIDs = @SearchTypeResult;
            } else {

                # combine both results (OR and AND)
                # remove all IDs from type result that we don't have in this search
                @ContactIDs = $Kernel::OM->Get('Main')->GetCombinedList(
                    ListA => \@SearchTypeResult,
                    ListB => \@ContactIDs
                );
            }
        }
    } else {

        # get full contact list
        my %ContactList = $Kernel::OM->Get('Contact')->ContactList(
            Valid => 0
        );
        @ContactIDs = %ContactList ? @{[keys %ContactList]} : ();
    }

    return @ContactIDs;
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
