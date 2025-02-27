# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::LinkObject::Person;

use strict;
use warnings;

our @ObjectDependencies = (
    'Contact',
    'LinkObject',
    'Log',
    'User',
);

=head1 NAME

Kernel::System::LinkObject::Person

=head1 SYNOPSIS

Ticket backend for the Person link object.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $LinkObjectPersonObject = $Kernel::OM->Get('LinkObject::Person');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ContactObject} = $Kernel::OM->Get('Contact');
    $Self->{LinkObject}         = $Kernel::OM->Get('LinkObject');
    $Self->{LogObject}          = $Kernel::OM->Get('Log');
    $Self->{UserObject}         = $Kernel::OM->Get('User');

    return $Self;
}

=item LinkListWithData()

fill up the link list with data

    $Success = $LinkObjectBackend->LinkListWithData(
        LinkList => $HashRef,
        UserID   => 1,
    );

=cut

sub LinkListWithData {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(LinkList UserID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check link list
    if ( ref $Param{LinkList} ne 'HASH' ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'LinkList must be a hash reference!',
        );
        return;
    }

    for my $LinkType ( keys %{ $Param{LinkList} } ) {

        for my $Direction ( keys %{ $Param{LinkList}->{$LinkType} } ) {

            PERSONID:
            for my $PersonID (
                keys %{ $Param{LinkList}->{$LinkType}->{$Direction} }
                )
            {
                my %PersonData;
                my $Person;
                if ( $LinkType eq 'Agent' ) {
                    %PersonData =
                        $Self->{UserObject}->GetUserData( User => $PersonID, );
                    $PersonData{Type} = 'Agent';
                }
                else {
                    %PersonData =
                        $Self->{ContactObject}
                        ->ContactGet( ID => $PersonID, );
                    $PersonData{Type} = 'Customer';
                }

                #                else {
##                    $Person = $1;
                #                    %PersonData = $Self->{ContactObject}->ContactGet(
                #                        User   => $PersonID,
                #                    );
                #                }
                # remove id from hash if person can not get
                if ( !%PersonData ) {
                    delete $Param{LinkList}->{$LinkType}->{$Direction}
                        ->{$PersonID};
                    next PERSONID;
                }

                # add person data
                $Param{LinkList}->{$LinkType}->{$Direction}->{$PersonID} =
                    \%PersonData;
            }
        }
    }

    return 1;
}

=item ObjectDescriptionGet()

return a hash of object descriptions

Return
    %Description = (
        Normal => "DocumentName",
        Long   => "DocumentSimple Data",
    );

    %Description = $LinkObject->ObjectDescriptionGet(
        Key     => 123,
        Mode    => 'Temporary',  # (optional)
        UserID  => 1,
    );

=cut

sub ObjectDescriptionGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Object Key UserID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # create description
    my %Description = (
        Normal => 'Person',
        Long   => 'Person',
    );

    return %Description if $Param{Mode} && $Param{Mode} eq 'Temporary';

    return %Description;
}

=item ObjectSearch()

return a hash list of the search results

Return
    $SearchList = {
        NOTLINKED => {
            Source => {
                12  => $DataOfItem12,
                212 => $DataOfItem212,
                332 => $DataOfItem332,
            },
        },
    };

    $SearchList = $LinkObjectBackend->ObjectSearch(
        SubObject    => 'Bla',     # (optional)
        SearchParams => $HashRef,  # (optional)
        UserID       => 1,
    );

=cut

sub ObjectSearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );
        return;
    }

    my %FoundPersons;
    my $Limit = (
        $Param{SearchParams}->{Limit}
        && $Param{SearchParams}->{Limit}[0]
    )
        ? $Param{SearchParams}->{Limit}[0]
        : 100;
    my $PersonType = (
        $Param{SearchParams}->{PersonType}
        && $Param{SearchParams}->{PersonType}[0]
    )
        ? $Param{SearchParams}->{PersonType}[0]
        : 'Customer';

    if ( $PersonType eq 'Customer' ) {

        # search customer
        my @ContactIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            Search => {
                AND => [
                    {
                        Field    => 'Fulltext',
                        Operator => 'EQ',
                        Value    => $Param{SearchParams}->{PersonAttributes}
                    },
                    {
                        Field    => 'Valid',
                        Operator => 'EQ',
                        Value    => 'valid'
                    }
                ]
            },
            Limit      => $Limit,
            ObjectType => 'Contact',
            Result     => 'ARRAY',
            UserID     => 1,
            UserType   => 'Agent'
        );

        for my $ID ( @ContactIDs ) {
            my %ContactData    = $Self->{ContactObject}->ContactGet( ID => $ID, );
            $ContactData{Type} = 'Customer';
            $FoundPersons{NOTLINKED}->{Source}->{$ID} = \%ContactData;
        }
    }
    else {

        # search agents in name fields and login...
        my %Users = $Self->{UserObject}->UserSearch(
            Search => $Param{SearchParams}->{PersonAttributes},
            Valid  => 1,
            Limit  => $Limit,
        );

        for my $ID ( keys %Users ) {
            my %UserData = $Self->{UserObject}->GetUserData( UserID => $ID, );
            $UserData{Type} = 'Agent';
            $FoundPersons{NOTLINKED}->{Source}->{ $UserData{UserLogin} } =
                \%UserData;
        }

        # search agents in email...
        # since replacing wildcard(s) as * is not done by the search method...
        $Param{SearchParams}->{PersonAttributes} =~ s/\*/%/g;

        # ...skipping other wildcards...

        my %Users2 = $Self->{UserObject}->UserSearch(
            Search => $Param{SearchParams}->{PersonAttributes},
            Valid  => 1,
            Limit  => $Limit
        );

        for my $ID ( keys %Users2 ) {
            my %UserData = $Self->{UserObject}->GetUserData( UserID => $ID, );
            $UserData{Type} = 'Agent';
            $FoundPersons{NOTLINKED}->{Source}->{ $UserData{UserLogin} } =
                \%UserData;
        }
    }

    return \%FoundPersons;
}

=item LinkAddPre()

link add pre event module

    $True = $LinkObject->LinkAddPre(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkAddPre(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkAddPre {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # delete old existing link if new link should be added
    if ( $Param{TargetObject} && $Param{TargetObject} eq 'Ticket' ) {
        my $LinkList = $Self->{LinkObject}->LinkList(
            Object  => 'Ticket',
            Key     => $Param{TargetKey},
            Object2 => 'Person',
            State   => 'Valid',
            UserID  => 1,
        );

        for my $LinkType ( keys %{ $LinkList->{Person} } ) {
            next
                if !$LinkList->{Person}->{$LinkType}->{Source}->{ $Param{Key} };

            my $True = $Self->{LinkObject}->LinkDelete(
                Object1 => 'Person',
                Key1    => $Param{Key},
                Object2 => 'Ticket',
                Key2    => $Param{TargetKey},
                Type    => 'Normal',
                UserID  => 1,
            );
        }

    }

    return 1;
}

=item LinkAddPost()

link add post event module

    $True = $LinkObject->LinkAddPost(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkAddPost(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkAddPost {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    return 1;
}

=item LinkDeletePre()

link delete pre event module

    $True = $LinkObject->LinkDeletePre(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkDeletePre(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkDeletePre {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    return 1;
}

=item LinkDeletePost()

link delete post event module

    $True = $LinkObject->LinkDeletePost(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkDeletePost(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkDeletePost {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    return 1;
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
