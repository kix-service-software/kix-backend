# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Auth::Sync::LDAP;

use strict;
use warnings;

use Net::LDAP;
use Net::LDAP::Util qw(escape_filter_value);
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Log',
    'User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # Debug 0=off 1=on
    $Self->{Debug} = 0;

    $Self->{Die}                    = $Param{Config}->{Die} || 1;
    $Self->{Host}                   = $Param{Config}->{Host} || '';
    $Self->{BaseDN}                 = $Param{Config}->{BaseDN} || '';
    $Self->{UID}                    = $Param{Config}->{UID} || 'uid';
    $Self->{SearchUserDN}           = $Param{Config}->{SearchUserDN} || '';
    $Self->{SearchUserPw}           = $Param{Config}->{SearchUserPw} || '';
    $Self->{GroupDN}                = $Param{Config}->{GroupDN} || '';
    $Self->{AccessAttr}             = $Param{Config}->{AccessAttr} || 'memberUid';
    $Self->{UserAttr}               = $Param{Config}->{UserAttr} || 'DN';
    $Self->{DestCharset}            = $Param{Config}->{Charset} || 'utf-8';
    $Self->{AlwaysFilter}           = $Param{Config}->{AlwaysFilter} || '';
    $Self->{Params}                 = $Param{Config}->{Params} || {};
    $Self->{Config}                 = $Param{Config}->{Config} || {};
    $Self->{ContactUserSync}        = $Param{Config}->{ContactUserSync} || {};
    $Self->{GroupDNBasedRoleSync}   = $Param{Config}->{GroupDNBasedRoleSync} || {};
    $Self->{AttributeBasedRoleSync} = $Param{Config}->{AttributeBasedRoleSync} || {};

    return $Self;
}

sub Sync {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{User} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need User!'
        );
        return;
    }
    $Param{User} = $Self->_ConvertTo( $Param{User}, 'utf-8' );

    my $RemoteAddr = $ENV{REMOTE_ADDR} || 'Got no REMOTE_ADDR env!';

    # remove leading and trailing spaces
    $Param{User} =~ s{ \A \s* ( [^\s]+ ) \s* \z }{$1}xms;

    # just in case for debug!
    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: '$Param{User}' tried to sync (REMOTE_ADDR: $RemoteAddr)",
        );
    }

    # ldap connect and bind (maybe with SearchUserDN and SearchUserPw)
    my $LDAP = Net::LDAP->new( $Self->{Host}, %{ $Self->{Params} } );
    if ( !$LDAP ) {
        if ( $Self->{Die} ) {
            die "Can't connect to $Self->{Host}: $@";
        }

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't connect to $Self->{Host}: $@",
        );
        return;
    }
    my $Result;
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
            Message  => 'First bind failed! ' . $Result->error(),
        );
        return;
    }

    # user quote
    my $Filter = "($Self->{UID}=" . escape_filter_value( $Param{User} ) . ')';

    # prepare filter
    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # perform user search
    $Result = $LDAP->search(
        base   => $Self->{BaseDN},
        filter => $Filter,
    );
    if ( $Result->code() ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Search failed! ($Self->{BaseDN}) filter='$Filter' " . $Result->error(),
        );
        return;
    }

    # get whole user dn
    my $UserDN;
    for my $Entry ( $Result->all_entries() ) {
        $UserDN = $Entry->dn();
    }

    # log if there is no LDAP user entry
    if ( !$UserDN ) {

        # failed login note
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: $Param{User} sync failed, no LDAP entry found!"
                . "BaseDN='$Self->{BaseDN}', Filter='$Filter', (REMOTE_ADDR: $RemoteAddr).",
        );

        # take down session
        $LDAP->unbind();
        return;
    }

    # get needed objects
    my $UserObject   = $Kernel::OM->Get('User');
    my $ConfigObject = $Kernel::OM->Get('Config');
    my $ContactObject = $Kernel::OM->Get('Contact');

    # get current user id
    my $UserID = $UserObject->UserLookup(
        UserLogin => $Param{User},
        Silent    => 1,
    );

    my $ContactID;

    # sync user from ldap
    my $ContactUserSync = $Self->{ContactUserSync};

    if (IsHashRefWithData($ContactUserSync)) {

        # get whole user dn
        my %SyncUser;
        for my $Entry ($Result->all_entries()) {
            for my $Key (sort keys %{$ContactUserSync}) {

                my $AttributeNames = $ContactUserSync->{$Key};
                if (ref $AttributeNames ne 'ARRAY') {
                    $AttributeNames = [ $AttributeNames ];
                }
                ATTRIBUTE_NAME:
                for my $AttributeName (@{$AttributeNames}) {
                    if ($AttributeName =~ /^SET:/i) {
                        $SyncUser{$Key} = substr($AttributeName, 4);
                        $SyncUser{$Key} =~ s/^\s+|\s+$//g;
                        last ATTRIBUTE_NAME;
                    }
                    elsif ($Entry->get_value($AttributeName)) {
                        $SyncUser{$Key} = $Entry->get_value($AttributeName);
                        last ATTRIBUTE_NAME;
                    }
                }

                # e. g. set utf-8 flag
                $SyncUser{$Key} = $Self->_ConvertFrom(
                    $SyncUser{$Key},
                    'utf-8',
                );
            }
        }

        # add new user
        if (%SyncUser && !$UserID) {
            $UserID = $UserObject->UserAdd(
                UserLogin    => $Param{User},
                %SyncUser,
                ValidID      => 1,
                ChangeUserID => 1,
            );
            if (!$UserID) {
                $Kernel::OM->Get('Log')->Log(
                    Priority  => 'error',
                    Message   => "Can't create user '$Param{User}' ($UserDN) in RDBMS!",
                );

                # take down session
                $LDAP->unbind();
                return;
            }
            else {
                my %ContactData;
                if ($SyncUser{Email}) {
                    %ContactData = $ContactObject->ContactSearch(
                        PostMasterSearch => $SyncUser{Email},
                        Silent           => 1,
                    );
                }
                elsif ($SyncUser{UserLogin}) {
                    %ContactData = $ContactObject->ContactSearch(
                        Login  => $SyncUser{UserLogin},
                        Silent => 1,
                    );
                }
                if ($ContactData{AssignedUserID} && $ContactData{AssignedUserID} != $UserID) {
                    $Kernel::OM->Get('Log')->Log(
                        LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                        Priority  => 'error',
                        Message   => "Can't assign user '$Param{User}' ($UserDN) to contact ($ContactData{ID}) in RDBMS! Contact already is already assigned to userid ($ContactData{AssignedUserID}).",
                    );

                    # take down session
                    $LDAP->unbind();
                    return;
                }
                $ContactID = $ContactObject->ContactAdd(
                    %SyncUser,
                    AssignedUserID        => $UserID,
                    PrimaryOrganisationID => 1,
                    ValidID               => 1,
                    UserID                => 1,
                );

                $Kernel::OM->Get('Log')->Log(
                    LogPrefix => 'Kernel::System::Auth::Sync::LDAP',
                    Priority  => 'notice',
                    Message   => "Initial data for '$Param{User}' ($UserDN) created in RDBMS.",
                );
            }
        }

        # update user attributes and contact attributes (only if changed)
        elsif (%SyncUser) {

            # get user data
            my %UserData = $UserObject->GetUserData(User => $Param{User});
            my %ContactData = $ContactObject->ContactGet(
                UserID => $UserData{UserID},
            );

            # check for changes on user
            my $AttributeChange;
            ATTRIBUTE:
            for my $Attribute (sort keys %SyncUser) {
                next ATTRIBUTE if ($SyncUser{$Attribute} && $UserData{$Attribute} && $SyncUser{$Attribute} eq $UserData{$Attribute});
                $AttributeChange = 1;
                last ATTRIBUTE;
            }

            if ($AttributeChange) {
                $UserObject->UserUpdate(
                    %UserData,
                    UserPw       => undef,
                    UserID       => $UserID,
                    UserLogin    => $Param{User},
                    %SyncUser,
                    UserType     => 'User',
                    ChangeUserID => 1,
                );
            }

            # check for changes on contact
            $AttributeChange = 0;
            ATTRIBUTE:
            for my $Attribute (sort keys %SyncUser) {
                next ATTRIBUTE if ($SyncUser{$Attribute} && $ContactData{$Attribute} && $SyncUser{$Attribute} eq $ContactData{$Attribute});
                $AttributeChange = 1;
                last ATTRIBUTE;
            }

            if ($AttributeChange) {
                $ContactObject->ContactUpdate(
                    %ContactData,
                    %SyncUser,
                    UserID         => 1,
                    AssignedUserID => $UserID,
                );
            }
        }
    }

    # get RoleObject
    my $RoleObject = $Kernel::OM->Get('Role');

    # get system roles and create lookup
    my %SystemRoles = $RoleObject->RoleList( Valid => 1 );
    my %SystemRolesByName = reverse %SystemRoles;

    # variable to store role permissions from ldap
    my %RolePermissionsFromLDAP;

    if ( IsHashRefWithData($Self->{GroupDNBasedRoleSync}) ) {

        # read and remember roles from ldap
        GROUPDN:
        for my $GroupDN ( sort keys %{$Self->{GroupDNBasedRoleSync}} ) {

            # search if we're allowed to
            my $Filter;
            if ( $Self->{UserAttr} eq 'DN' ) {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value($UserDN) . ')';
            }
            else {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value( $Param{User} ) . ')';
            }
            my $Result = $LDAP->search(
                base   => $GroupDN,
                filter => $Filter,
            );
            if ( $Result->code() ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Search failed! ($GroupDN) filter='$Filter' " . $Result->error(),
                );
                next GROUPDN;
            }

            # extract it
            my $Valid;
            for my $Entry ( $Result->all_entries() ) {
                $Valid = $Entry->dn();
            }

            # log if there is no LDAP entry
            if ( !$Valid ) {

                # failed login note
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "User: $Param{User} not in "
                        . "GroupDN='$GroupDN', Filter='$Filter'! (REMOTE_ADDR: $RemoteAddr).",
                );
                next GROUPDN;
            }

            # remember role permissions
            my %SyncRoles = %{ $Self->{GroupDNBasedRoleSync}->{$GroupDN} };
            SYNCROLE:
            for my $SyncRole ( sort keys %SyncRoles ) {

                # only for valid roles
                if ( !$SystemRolesByName{$SyncRole} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'notice',
                        Message => "Invalid role '$SyncRole' in GroupDNBasedRoleSync!"
                    );
                    next SYNCROLE;
                }

                # set/overwrite remembered permissions
                $RolePermissionsFromLDAP{ $SystemRolesByName{$SyncRole} } =
                    $SyncRoles{$SyncRole};
            }
        }
    }

    if ( IsHashRefWithData($Self->{AttributeBasedRoleSync}) ) {

        # build filter
        my $Filter = "($Self->{UID}=" . escape_filter_value( $Param{User} ) . ')';

        # perform search
        $Result = $LDAP->search(
            base   => $Self->{BaseDN},
            filter => $Filter,
        );
        if ( $Result->code() ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Search failed! ($Self->{BaseDN}) filter='$Filter' " . $Result->error(),
            );
        }
        else {
            my %SyncConfig = %{$Self->{AttributeBasedRoleSync}};
            for my $Attribute ( sort keys %SyncConfig ) {

                my %AttributeValues = %{ $SyncConfig{$Attribute} };
                ATTRIBUTEVALUE:
                for my $AttributeValue ( sort keys %AttributeValues ) {

                    for my $Entry ( $Result->all_entries() ) {

                        # Check if configured value exists in values of role attribute
                        # If yes, add sync roles to the user
                        my $GotValue;
                        my @Values = $Entry->get_value($Attribute);
                        VALUE:
                        for my $Value (@Values) {
                            next VALUE if $Value !~ m{ \A \Q$AttributeValue\E \z }xmsi;
                            $GotValue = 1;
                            last VALUE;
                        }
                        next ATTRIBUTEVALUE if !$GotValue;

                        # remember role permissions
                        my %SyncRoles = %{ $AttributeValues{$AttributeValue} };
                        SYNCROLE:
                        for my $SyncRole ( sort keys %SyncRoles ) {

                            # only for valid roles
                            if ( !$SystemRolesByName{$SyncRole} ) {
                                $Kernel::OM->Get('Log')->Log(
                                    Priority => 'notice',
                                    Message =>
                                        "Invalid role '$SyncRole' in AttributeBasedGroupDNBasedRoleSync!",
                                );
                                next SYNCROLE;
                            }

                            # set/overwrite remembered permissions
                            $RolePermissionsFromLDAP{ $SystemRolesByName{$SyncRole} } =
                                $SyncRoles{$SyncRole};
                        }
                    }
                }
            }
        }
    }

    # compare role permissions from ldap with current user role permissions and update if necessary
    if (%RolePermissionsFromLDAP) {

        # get current user roles
        my %UserRoles = $UserObject->RoleList(
            UserID => $UserID,
        );

        ROLEID:
        for my $RoleID ( sort keys %SystemRoles ) {

            # if old and new permission for role matches, do nothing
            if (
                ( $UserRoles{$RoleID} && $RolePermissionsFromLDAP{$RoleID} )
                ||
                ( !$UserRoles{$RoleID} && !$RolePermissionsFromLDAP{$RoleID} )
                )
            {
                next ROLEID;
            }

            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "User: '$Param{User}' sync ldap role $SystemRoles{$RoleID}!",
            );
            $RoleObject->RoleUserAdd(
                AssignUserID  => $UserID,
                RoleID        => $RoleID,
                UserID        => 1,
#                Active => $RolePermissionsFromLDAP{$RoleID} || 0,
            );
        }
    }

    # take down session
    $LDAP->unbind();

    return $Param{User};
}

sub _ConvertTo {
    my ( $Self, $Text, $Charset ) = @_;

    return if !defined $Text;

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    if ( !$Charset || !$Self->{DestCharset} ) {
        $EncodeObject->EncodeInput( \$Text );
        return $Text;
    }

    # convert from input charset ($Charset) to directory charset ($Self->{DestCharset})
    return $EncodeObject->Convert(
        Text => $Text,
        From => $Charset,
        To   => $Self->{DestCharset},
    );
}

sub _ConvertFrom {
    my ( $Self, $Text, $Charset ) = @_;

    return if !defined $Text;

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    if ( !$Charset || !$Self->{DestCharset} ) {
        $EncodeObject->EncodeInput( \$Text );
        return $Text;
    }

    # convert from directory charset ($Self->{DestCharset}) to input charset ($Charset)
    return $EncodeObject->Convert(
        Text => $Text,
        From => $Self->{DestCharset},
        To   => $Charset,
    );
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
