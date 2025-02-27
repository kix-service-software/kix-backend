# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::LinkObject::FAQArticle;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Config
    FAQ
    Log
    ObjectSearch
);

=head1 NAME

Kernel::System::LinkObject::FAQ

=head1 SYNOPSIS

FAQ backend for the link object.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $FAQObjectBackend = $Kernel::OM->Get('LinkObject::FAQ');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item LinkListWithData()

fill up the link list with data

    $Success = $FAQLinkObject->LinkListWithData(
        LinkList => $HashRef,
        UserID   => 1,
    );

=cut

sub LinkListWithData {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(LinkList UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # check link list
    if ( ref $Param{LinkList} ne 'HASH' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'LinkList must be a hash reference!',
        );

        return;
    }

    # get FAQ object
    my $FAQObject = $Kernel::OM->Get('FAQ');

    for my $LinkType ( sort keys %{ $Param{LinkList} } ) {

        for my $Direction ( sort keys %{ $Param{LinkList}->{$LinkType} } ) {

            FAQID:
            for my $FAQID ( sort keys %{ $Param{LinkList}->{$LinkType}->{$Direction} } ) {

                # get FAQ data
                my %FAQData = $FAQObject->FAQGet(
                    ItemID     => $FAQID,
                    ItemFields => 1,
                    UserID     => $Param{UserID},
                );

                # remove id from hash if no FAQ data was found
                if ( !%FAQData ) {
                    delete $Param{LinkList}->{$LinkType}->{$Direction}->{$FAQID};
                    next FAQID;
                }

                # add FAQ data
                $Param{LinkList}->{$LinkType}->{$Direction}->{$FAQID} = \%FAQData;
            }
        }
    }

    return 1;
}

=item ObjectDescriptionGet()

return a hash of object descriptions

Return
    %Description = (
        Normal => "FAQ# 1234",
        Long   => "FAQ# 1234: FAQTitle",
    );

    %Description = $LinkObject->ObjectDescriptionGet(
        Key     => 123,
        UserID  => 1,
    );

=cut

sub ObjectDescriptionGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Object Key UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # create description
    my %Description = (
        Normal => 'FAQ',
        Long   => 'FAQ',
    );

    return %Description if $Param{Mode} && $Param{Mode} eq 'Temporary';

    # get FAQ
    my %FAQ = $Kernel::OM->Get('FAQ')->FAQGet(
        ItemID     => $Param{Key},
        ItemFields => 1,
        UserID     => $Param{UserID},
    );

    return if !%FAQ;

    # define description text
    my $FAQHook         = $Kernel::OM->Get('Config')->Get('FAQ::FAQHook');
    my $DescriptionText = "$FAQHook $FAQ{Number}";

    # create description
    %Description = (
        Normal => $DescriptionText,
        Long   => "$DescriptionText: $FAQ{Title}",
    );

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
        Search       => {
            AND => [
                {}
            ]
            OR  => [
                {}
            ]
        },                         # (optional)
        Sort         => [
            {}
        ],                         # (optional)
        UserType     => 1,
        UserID       => 1,
    );

=cut

sub ObjectSearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );

        return;
    }

    my @FAQIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        %Param,
        ObjectType => 'FAQArticle',
        Result     => 'ARRAY',
        Limit      => 50,
        UserID     => $Param{UserID},
        UserType   => $Param{UserType}
    );

    my %SearchList;
    FAQID:
    for my $FAQID (@FAQIDs) {

        # get FAQ data
        my %FAQData = $Kernel::OM->Get('FAQ')->FAQGet(
            ItemID     => $FAQID,
            ItemFields => 1,
            UserID     => $Param{UserID},
        );

        next FAQID if !%FAQData;

        # add FAQ data
        $SearchList{NOTLINKED}->{Source}->{$FAQID} = \%FAQData;
    }

    return \%SearchList;
}

=item LinkAddPre()

link add pre event module

    $True = $FAQLinkObject->LinkAddPre(
        Key          => 123,
        SourceObject => 'FAQ',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $FAQLinkObject->LinkAddPre(
        Key          => 123,
        TargetObject => 'FAQ',
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
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    return 1;
}

=item LinkAddPost()

link add pre event module

    $True = $FAQLinkObject->LinkAddPost(
        Key          => 123,
        SourceObject => 'FAQ',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $FAQLinkObject->LinkAddPost(
        Key          => 123,
        TargetObject => 'FAQ',
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
            $Kernel::OM->Get('Log')->Log(
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

    $True = $FAQLinkObject->LinkDeletePre(
        Key          => 123,
        SourceObject => 'FAQ',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $FAQLinkObject->LinkDeletePre(
        Key          => 123,
        TargetObject => 'FAQ',
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
            $Kernel::OM->Get('Log')->Log(
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

    $True = $FAQLinkObject->LinkDeletePost(
        Key          => 123,
        SourceObject => 'FAQ',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $FAQLinkObject->LinkDeletePost(
        Key          => 123,
        TargetObject => 'FAQ',
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
            $Kernel::OM->Get('Log')->Log(
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
