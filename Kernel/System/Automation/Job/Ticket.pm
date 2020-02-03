# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::Job::Ticket;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::Job::Common);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Automation::Job::Ticket - job type ticket for automation lib

=head1 SYNOPSIS

Handles ticket based jobs.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

Run this job module. Returns 1 if the job was executed successful.

Example:
    my $Result = $Object->Run(
        Filter => {}         # optional, filter for objects
        Data   => {},        # optional, contains the relevant data given by an event or otherwise
        UserID => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Filter UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    my @TicketIDs;

    # execute a ticket search if we have no ObjectIDs given
    if ( IsHashRefWithData($Param{Data}) && $Param{Data}->{TicketID} ) {
        @TicketIDs = $Param{Data}->{TicketID};
    }
    else {
        @TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
            Result => 'ARRAY'
        );
    }

    # filter given objects
    if ( IsHashRefWithData($Param{Filter}) ) {

        # get dynamic fields
        my $DynamicFieldList = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
            Valid      => 1,
            ObjectType => ['Ticket'],
        );

        # create a dynamic field config lookup table
        my %DynamicFieldConfigLookup;
        for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {
            $DynamicFieldConfigLookup{ $DynamicFieldConfig->{Name} } = $DynamicFieldConfig;
        }

        my @Result;
        foreach my $TicketID ( sort @TicketIDs ) {
            my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
                TicketID      => $TicketID,
                UserID        => $Param{UserID},
                DynamicFields => 1
            );

            if ( !%Ticket ) {
                $Kernel::OM->Get('Kernel::System::Automation')->LogError(
                    Referrer => $Self,
                    Message  => "Ticket with ID $TicketID not found!",
                    UserID   => $Param{UserID},
                );                
                return;
            }

            my $Accepted = $Self->_Filter(
                Data   => $Param{Data},
                Ticket => \%Ticket,
                Filter => $Param{Filter},
                UserID => $Param{UserID},
                DynamicFieldConfigLookup => \%DynamicFieldConfigLookup
            );

            if ( $Accepted ) {
                push @Result, $TicketID;
            }
        }
        @TicketIDs = @Result;
    }

    return @TicketIDs;
}

sub _Filter {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Ticket Filter UserID DynamicFieldConfigLookup)) {
        return if !$Param{$Needed};
    }

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    KEY:
    for my $Key ( sort keys %{ $Param{Filter} } ) {

        # ignore not ticket or article related attributes
        next KEY if $Key !~ /^(Ticket|Article)::(.*?)$/;

        # store extracted attribute name
        my $Attribute = $2;

        my %Article;
        if ( $Param{Data}->{ArticleID} ) {
            %Article = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleGet(
                ArticleID     => $Param{Data}->{ArticleID},
                UserID        => $Param{UserID},
                DynamicFields => 0,
            );
        }

        # ignore anything that isn't ok
        next KEY if !$Param{Filter}->{$Key};
        next KEY if !@{ $Param{Filter}->{$Key} };
        next KEY if !defined $Param{Filter}->{$Key}->[0];
        my $Match = 0;

        VALUE:
        for my $Value ( @{ $Param{Filter}->{$Key} } ) {
            next VALUE if !defined $Value;

            if ( $Key =~ /^Ticket::/ ) {
                # check if key is a search dynamic field
                if ( $Attribute =~ m{\A DynamicField_(.*?)$}xms ) {

                    # remove search prefix
                    my $DynamicFieldName = $1;

                    # get the dynamic field config for this field
                    my $DynamicFieldConfig = $Param{DynamicFieldConfigLookup}->{$DynamicFieldName};

                    last VALUE if !$DynamicFieldConfig;

                    # here we are using the same behaviour as in NotificationEvent at the moment
                    my $IsNotificationEventCondition = $DynamicFieldBackendObject->HasBehavior(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        Behavior           => 'IsNotificationEventCondition',
                    );

                    last VALUE if !$IsNotificationEventCondition;

                    # Get match value from the dynamic field backend, if applicable (bug#12257).
                    my $MatchValue;
                    my $SearchFieldParameter = $DynamicFieldBackendObject->SearchFieldParameterBuild(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        Profile            => {
                            $Key => $Value,
                        },
                    );
                    if ( defined $SearchFieldParameter->{Parameter}->{Equals} ) {
                        $MatchValue = $SearchFieldParameter->{Parameter}->{Equals};
                    }
                    else {
                        $MatchValue = $Value;
                    }

                    $Match = $DynamicFieldBackendObject->ObjectMatch(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        Value              => $MatchValue,
                        ObjectAttributes   => $Param{Ticket},
                    );

                    last VALUE if $Match;
                }
                else {

                    if ( $Param{Ticket}->{$Attribute} && $Value eq $Param{Ticket}->{$Attribute} ) {
                        $Match = 1;
                        last VALUE;
                    }
                }
            }
            elsif ( $Key =~ /^Article::/ ) {
                next KEY if !IsHashRefWithData(\%Article);

                if ( $Article{$Attribute} && $Attribute =~ /(Body|Subject)/ && $Article{$Attribute} =~ /\Q$Value\E/i ) {
                    $Match = 1;
                    last VALUE;
                }
                elsif ( $Article{$Attribute} && $Value eq $Article{$Attribute} ) {
                    $Match = 1;
                    last VALUE;
                }
            }
        }

        return if !$Match;
    }

    return 1;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
