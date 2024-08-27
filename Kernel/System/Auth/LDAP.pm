# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Auth::LDAP;

use strict;
use warnings;

use Net::LDAP;
use Net::LDAP::Util qw(escape_filter_value);

our @ObjectDependencies = (
    'Config',
    'LDAPUtils',
    'Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # Debug 0=off 1=on
    $Self->{Debug}            = $Param{Config}->{Debug} || 0;
    $Self->{Die}              = $Param{Config}->{Die} // 1;
    $Self->{Host}             = $Param{Config}->{Host} || '';
    $Self->{BaseDN}           = $Param{Config}->{BaseDN} || '';
    $Self->{UID}              = $Param{Config}->{UID} || '';
    $Self->{SearchUserDN}     = $Param{Config}->{SearchUserDN} || '';
    $Self->{SearchUserPw}     = $Param{Config}->{SearchUserPw} || '';
    $Self->{GroupDN}          = $Param{Config}->{GroupDN} || '';
    $Self->{AuthAttr}         = $Param{Config}->{AuthAttr} || $Self->{UID};     # optional Auth attribute
    $Self->{AccessAttr}       = $Param{Config}->{AccessAttr} || 'memberUid';
    $Self->{UserAttr}         = $Param{Config}->{UserAttr} || 'DN';
    $Self->{DestCharset}      = $Param{Config}->{Charset} || 'utf-8';
    $Self->{AlwaysFilter}     = $Param{Config}->{AlwaysFilter} || '';
    $Self->{Params}           = $Param{Config}->{Params} || {};

    $Self->{EmailUniqueCheck} = $Kernel::OM->Get('Config')->Get('ContactEmailUniqueCheck');

    return $Self;
}

sub GetAuthMethod {
    my ( $Self, %Param ) = @_;

    return {
        Type    => 'LOGIN',
        PreAuth => 0
    };
}

sub Auth {
    my ( $Self, %Param ) = @_;

    # do nothing if we have no relevant data for us
    return if !$Param{User} || !$Param{Pw};

    # we can't accept email as AuthAttr without unique email addresses
    if ( $Self->{AuthAttr} && $Self->{AuthAttr} =~ /mail/i && !$Self->{EmailUniqueCheck} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "LDAP Auth: AuthAttr \"$Self->{AuthAttr}\" not possible since \"ContactEmailUniqueCheck\" option is not active (Backend: \"$Self->{Config}->{Name}\")!",
        );
        return;
    }

    $Param{User} = $Kernel::OM->Get('LDAPUtils')->Convert(
        Text => $Param{User},
        From => 'utf-8',
        To   => $Self->{DestCharset},
    );
    $Param{Pw}   = $Kernel::OM->Get('LDAPUtils')->Convert(
        Text => $Param{Pw},
        From => 'utf-8',
        To   => $Self->{DestCharset},
    );

    # get params
    my $RemoteAddr = $ENV{REMOTE_ADDR} || 'Got no REMOTE_ADDR env!';

    # remove leading and trailing spaces
    $Param{User} =~ s/^\s+//;
    $Param{User} =~ s/\s+$//;

    # Convert username to lower case letters
    if ( $Self->{UserLowerCase} ) {
        $Param{User} = lc $Param{User};
    }

    # add user suffix
    if ( $Self->{UserSuffix} ) {
        $Param{User} .= $Self->{UserSuffix};

        # just in case for debug
        if ( $Self->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "User: ($Param{User}) added $Self->{UserSuffix} to username! (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\")",
            );
        }
    }

    # just in case for debug!
    if ( $Self->{Debug} > 2 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: '$Param{User}' tried to authenticate with Pw: '$Param{Pw}' "
                . "(REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\")",
        );
    }

    # ldap connect and bind (maybe with SearchUserDN and SearchUserPw)
    my $LDAP = Net::LDAP->new( $Self->{Host}, %{ $Self->{Params} } );
    if ( !$LDAP ) {
        $Kernel::OM->Get('Log')->Log(
           Priority => 'error',
           Message  => "Can't connect to $Self->{Host}: $@" . "(REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
        );
        return;
    }
    my $Result = '';
    if ( $Self->{SearchUserDN} && $Self->{SearchUserPw} ) {
        $Result = $LDAP->bind(
            dn       => $Self->{SearchUserDN},
            password => $Self->{SearchUserPw}
        );
    }
    else {
        $Result = $LDAP->bind();
    }
    if ( $Result->code() ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'First bind failed! ' . $Result->error() . "(REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
        );
        $LDAP->disconnect();
        return;
    }

    # prepare filter
    my $Filter = "($Self->{AuthAttr}=" . escape_filter_value( $Param{User} ) . ')';
    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # perform user search
    $Result = $LDAP->search(
        base   => $Self->{BaseDN},
        filter => $Filter,
        attrs  => [ $Self->{UID} ],
    );

    if ( $Result->code() ) {
        if ( $Self->{AuthAttr} ne $Self->{UID} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "AuthAttr Search failed. " . $Result->error() . " BaseDN='$Self->{BaseDN}', filter='$Filter', (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\"). Retry Search with UID",
            );

            # prepare filter with uid
            $Filter = "($Self->{UID}=" . escape_filter_value( $Param{User} ) . ')';
            if ( $Self->{AlwaysFilter} ) {
                $Filter = "(&$Self->{AlwaysFilter}$Filter)";
            }

            # perform user search
            $Result = $LDAP->search(
                base   => $Self->{BaseDN},
                filter => $Filter,
                attrs  => [ $Self->{UID} ],
            );
            if ( $Result->code() ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "UID Search failed! " . $Result->error() . " BaseDN='$Self->{BaseDN}', filter='$Filter', (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
                );

                # take down session
                $LDAP->unbind();
                $LDAP->disconnect();

                return;
            }
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "AuthAttr Search failed! " . $Result->error() . " BaseDN='$Self->{BaseDN}', filter='$Filter', (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
            );

            # take down session
            $LDAP->unbind();
            $LDAP->disconnect();

            return;
        }
    }

    # get whole user dn
    my $UserDN = '';
    my $User   = '';
    for my $Entry ( $Result->all_entries() ) {
        $UserDN = $Entry->dn();
        $User   = $Entry->get_value( $Self->{UID} );
    }

    # log if there is no LDAP user entry
    if ( !$UserDN || !$User ) {
        if ( $Self->{AuthAttr} ne $Self->{UID} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "User: $Param{User} authentication failed, no LDAP entry with AuthAttr found! "
                    . "BaseDN='$Self->{BaseDN}', Filter='$Filter', (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\"). Retry Search with UID",
            );

            # prepare filter with uid
            $Filter = "($Self->{UID}=" . escape_filter_value( $Param{User} ) . ')';
            if ( $Self->{AlwaysFilter} ) {
                $Filter = "(&$Self->{AlwaysFilter}$Filter)";
            }

            # perform user search
            $Result = $LDAP->search(
                base   => $Self->{BaseDN},
                filter => $Filter,
                attrs  => [ $Self->{UID} ],
            );
            if ( $Result->code() ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "UID Search failed! " . $Result->error() . " BaseDN='$Self->{BaseDN}', filter='$Filter', (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
                );

                # take down session
                $LDAP->unbind();
                $LDAP->disconnect();

                return;
            }

            for my $Entry ( $Result->all_entries() ) {
                $UserDN = $Entry->dn();
                $User   = $Entry->get_value( $Self->{UID} );
            }
            if ( !$UserDN || !$User ) {
                # failed login note
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "User: $Param{User} authentication failed, no LDAP entry with UID found! "
                        . "BaseDN='$Self->{BaseDN}', Filter='$Filter', (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
                );

                # take down session
                $LDAP->unbind();
                $LDAP->disconnect();

                return;
            }
        }
        else {
            # failed login note
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "User: $Param{User} authentication failed, no LDAP entry with AuthAttr found! "
                    . "BaseDN='$Self->{BaseDN}', Filter='$Filter', (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
            );

            # take down session
            $LDAP->unbind();
            $LDAP->disconnect();

            return;
        }
    }

    $User = $Kernel::OM->Get('LDAPUtils')->Convert(
        Text => $User,
        From => 'utf-8',
        To   => $Self->{DestCharset},
    );

    # check if user need to be in a group!
    if ( $Self->{AccessAttr} && $Self->{GroupDN} ) {

        # just in case for debug
        if ( $Self->{Debug} > 0 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => 'check for groupdn!',
            );
        }

        # search if we're allowed to
        my $Filter2 = '';
        if ( $Self->{UserAttr} eq 'DN' ) {
            $Filter2 = "($Self->{AccessAttr}=" . escape_filter_value($UserDN) . ')';
        }
        else {
            $Filter2 = "($Self->{AccessAttr}=" . escape_filter_value( $User ) . ')';
        }
        my $Result2 = $LDAP->search(
            base   => $Self->{GroupDN},
            filter => $Filter2,
            attrs  => ['1.1'],
        );
        if ( $Result2->code() ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Search failed! base='$Self->{GroupDN}', filter='$Filter2', "
                    . $Result2->error() . "(REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
            );

            # take down session
            $LDAP->unbind();
            $LDAP->disconnect();

            return;
        }

        # extract it
        my $GroupDN = '';
        for my $Entry ( $Result2->all_entries() ) {
            $GroupDN = $Entry->dn();
        }

        # log if there is no LDAP entry
        if ( !$GroupDN ) {

            # failed login note
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "User: $Param{User} authentication failed, no LDAP group entry found "
                    . "GroupDN='$Self->{GroupDN}', Filter='$Filter2'! (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
            );

            # take down session
            $LDAP->unbind();
            $LDAP->disconnect();

            return;
        }
    }

    # bind with user data -> real user auth.
    $Result = $LDAP->bind(
        dn       => $UserDN,
        password => $Param{Pw}
    );
    if ( $Result->code() ) {

        # failed login note
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: $Param{User} ($UserDN) authentication failed: '"
                . $Result->error()
                . "' (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
        );

        # take down session
        $LDAP->unbind();
        $LDAP->disconnect();

        return;
    }

    # login note
    $Kernel::OM->Get('Log')->Log(
        Priority => 'notice',
        Message  => "User: $Param{User} ($UserDN) authentication ok (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
    );

    # take down session
    $LDAP->unbind();
    $LDAP->disconnect();

    return $User;
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
