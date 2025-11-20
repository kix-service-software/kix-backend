# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FAQ::Category;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    ClientRegistration
    Cache
    DB
    Log
    Valid
);

=head1 NAME

Kernel::System::FAQ::Category - sub module of Kernel::System::FAQ

=head1 SYNOPSIS

All FAQ category functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item CategoryAdd()

add a category

    my $CategoryID = $FAQObject->CategoryAdd(
        Name     => 'CategoryA',
        Comment  => 'Some comment',
        ParentID => 2,
        ValidID  => 1,
        UserID   => 1,
    );

Returns:

    $CategoryID = 34;               # or undef if category could not be added

=cut

sub CategoryAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Name UserID)) {
        if ( !$Param{$Argument} ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # check needed stuff
    if ( !defined $Param{ParentID} ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ParentID!",
        );

        return;
    }

    # check that ParentID is not an empty string but number 0 is allowed
    if ( $Param{ParentID} eq '' ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "ParentID cannot be empty!",
        );

        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # insert record
    return if !$DBObject->Do(
        SQL => '
            INSERT INTO faq_category (name, parent_id, comments, valid_id, created, created_by,
                changed, changed_by)
            VALUES ( ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{ParentID}, \$Param{Comment}, \$Param{ValidID},
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get new category id
    return if !$DBObject->Prepare(
        SQL => '
            SELECT id
            FROM faq_category
            WHERE name = ? AND parent_id = ?',
        Bind  => [ \$Param{Name}, \$Param{ParentID} ],
        Limit => 1,
    );

    my $CategoryID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $CategoryID = $Row[0];
    }

    # log notice
    $Kernel::OM->Get('Log')->Log(
        Priority => 'notice',
        Message  => "FAQCategory: '$Param{Name}' CategoryID: '$CategoryID' "
            . "created successfully ($Param{UserID})!",
    );

    # clear cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'FAQ.Category',
        ObjectID  => $CategoryID,
    );

    return $CategoryID;
}

=item CategoryCount()

Count the number of categories.

    my $CategoryCount = $FAQObject->CategoryCount(
        ParentIDs => [ 1, 2, 3, 4 ],
        UserID    => 1,
    );

Returns:

    $CategoryCount = 6;

=cut

sub CategoryCount {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );

        return;
    }

    # check needed stuff
    if ( !defined $Param{ParentIDs} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ParentIDs!',
        );

        return;
    }

    # build SQL
    my $SQL = '
        SELECT COUNT(*)
        FROM faq_category
        WHERE valid_id IN ('
        . join ', ', $Kernel::OM->Get('Valid')->ValidIDsGet()
        . ')';

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # parent ids are given
    if ( defined $Param{ParentIDs} ) {

        # integer quote the parent ids
        for my $ParentID ( @{ $Param{ParentIDs} } ) {
            $ParentID = $DBObject->Quote( $ParentID, 'Integer' );
        }

        # create string
        my $InString = join ', ', @{ $Param{ParentIDs} };

        $SQL .= ' AND parent_id IN (' . $InString . ')';
    }

    # add group by
    $SQL .= ' GROUP BY parent_id';

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Limit => 200,
    );

    my $Count = 0;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Count = $Row[0];
    }

    return $Count;
}

=item CategoryDelete()

Delete a category.

    my $DeleteSuccess = $FAQObject->CategoryDelete(
        CategoryID => 123,
        UserID      => 1,
    );

Returns:

    DeleteSuccess = 1;              # or undef if category could not be deleted

=cut

sub CategoryDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Attribute (qw(CategoryID UserID)) {
        if ( !$Param{$Attribute} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Attribute!",
            );

            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # delete the category
    return if !$DBObject->Do(
        SQL => '
            DELETE FROM faq_category
            WHERE id = ?',
        Bind => [ \$Param{CategoryID} ],
    );

    # clear cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # reset cache object search
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'FAQ.Category',
        ObjectID  => $Param{CategoryID},
    );

    return 1;
}

=item CategoryDuplicateCheck()

check a category for duplicate name under the same parent

    my $Exists = $FAQObject->CategoryDuplicateCheck(
        CategoryID => 1,
        Name       => 'Some Name',
        ParentID   => 1,
        UserID     => 1,
    );

Returns:

    $Exists = 1;                # if category name already exists with the same parent
                                # or 0 if the name does not exists with the same parent

=cut

sub CategoryDuplicateCheck {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );

        return;
    }

    # set defaults
    $Param{Name} //= '';
    $Param{ParentID} ||= 0;
    my @Values;
    push @Values, \$Param{Name};
    push @Values, \$Param{ParentID};

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # db quote
    $Param{ParentID} = $DBObject->Quote( $Param{ParentID}, 'Integer' );

    # build SQL
    my $SQL = '
        SELECT id
        FROM faq_category
        WHERE name = ?
            AND parent_id = ?
        ';
    if ( defined $Param{CategoryID} ) {
        $SQL .= " AND id != ?";
        push @Values, \$Param{CategoryID};

    }

    # prepare SQL statement
    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Values,
        Limit => 1,
    );

    # fetch the result
    my $Exists;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Exists = 1;
    }

    return $Exists;
}

=item CategoryGet()

get a category as hash

    my %Category = $FAQObject->CategoryGet(
        CategoryID => 1,
        UserID     => 1,
    );

Returns:

    %Category = (,
        ID         => 2,
        ParentID   => 0,
        Name       => 'My Category',
        Comment    => 'This is my first category.',
        ValidID    => 1,
        CreateTime => '2010-04-07 15:41:15',
        CreateBy   => 1,
        ChangeTime => '2010-04-07 15:41:15',
        ChangeBy   => 1
    );

=cut

sub CategoryGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );

        return;
    }

    # check needed stuff
    if ( !defined $Param{CategoryID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need CategoryID!',
        );

        return;
    }

    # check cache
    my $CacheKey = 'FAQ::CategoryGet::' . $Param{CategoryID};

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    my $Cache = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # SQL
    return if !$DBObject->Prepare(
        SQL => '
            SELECT id, parent_id, name, comments, valid_id, created, created_by, changed, changed_by
            FROM faq_category
            WHERE id = ?',
        Bind  => [ \$Param{CategoryID} ],
        Limit => 1,
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        %Data = (
            ID         => $Row[0],
            ParentID   => $Row[1],
            Name       => $Row[2],
            Comment    => $Row[3],
            ValidID    => $Row[4],
            CreateTime => $Row[5],
            CreateBy   => $Row[6],
            ChangeTime => $Row[7],
            ChangeBy   => $Row[8],
        );
    }

    # build fullname
    if ( $Data{ParentID} ) {
        my %ParentCategory = $Self->CategoryGet(
            CategoryID => $Data{ParentID},
            UserID     => 1,
        );
        $Data{Fullname} = $ParentCategory{Fullname}.'::'.$Data{Name};
    }
    else {
        $Data{Fullname} = $Data{Name};
    }

    # cache result
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%Data,
        TTL   => $Self->{CacheTTL}
    );

    return %Data;
}

=item CategoryList()

get the category list as hash

    my $CategoryHashRef = $FAQObject->CategoryList(
        Valid  => 1,   # (optional)
        UserID => 1,
    );

Returns:

    $CategoryHashRef = {
        0 => {
            1 => 'Misc',
            2 => 'My Category',
        },
        2 => {
            3 => 'Sub Category A',
            4 => 'Sub Category B',
        },
    };

=cut

sub CategoryList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );

        return;
    }

    # set default
    my $Valid = 0;
    if ( defined $Param{Valid} ) {
        $Valid = $Param{Valid};
    }

    # check cache
    my $CacheKey = 'FAQ::CategoryList::' . $Valid;

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    my $Cache = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    return $Cache if $Cache;

    # build SQL
    my $SQL = '
        SELECT id, parent_id, name
        FROM faq_category';
    if ($Valid) {

        # get the valid ids
        $SQL .= ' WHERE valid_id IN ('
            . join ', ', $Kernel::OM->Get('Valid')->ValidIDsGet()
            . ')';
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # prepare SQL statement
    return if !$DBObject->Prepare( SQL => $SQL );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[1] }->{ $Row[0] } = $Row[2];
    }

    # cache result
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%Data,
        TTL   => $Self->{CacheTTL}
    );

    return \%Data;
}

=item CategoryLookup()

get id or name of a category

    my $Category = $FAQObject->CategoryLookup( CategoryID => $CategoryID );

    my $CategoryID = $FAQObject->CategoryLookup( Name => $Category );

=cut

sub CategoryLookup {
    my ( $Self, %Param ) = @_;
    my $Key;
    my $Value;
    my $ReturnData;

    # check needed stuff
    if ( !$Param{Name} && !$Param{CategoryID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Got no Name or CategoryID!',
            );
        }

        return;
    }

    if ( $Param{CategoryID} ) {
        $Key   = 'CategoryID';
        $Value = $Param{CategoryID};

        my %Category = $Self->CategoryGet(
            CategoryID => $Param{CategoryID},
            UserID     => 1,
        );
        $ReturnData = $Category{Name};
    }
    else {
        $Key   = 'Name';
        $Value = $Param{Name};

        my $CategoryList = $Self->CategorySearch(
            Name   => $Param{Name},
            UserID => 1,
        );
        if ( IsArrayRefWithData($CategoryList) ) {
            $ReturnData = $CategoryList->[0];
        }
    }

    # check if data exists
    if ( !defined $ReturnData ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No $Key for $Value found!",
            );
        }

        return;
    }

    return $ReturnData;
}

=item CategorySearch()

get the category search as an array ref

    my $CategoryIDArrayRef = $FAQObject->CategorySearch(
        Name        => 'Test',
        ParentID    => 3,
        ParentIDs   => [ 1, 3, 8 ],
        CategoryIDs => [ 2, 5, 7 ],
        ValidIDs    => [ 1, 2 ],
        OrderBy     => 'Name',
        SortBy      => 'down',
        Limit       => 500,
        UserID      => 1,
    );

Returns:

    $CategoryIDArrayRef = [
        2,
    ];

=cut

sub CategorySearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );

        return;
    }

    # SQL
    my $SQL = '
        SELECT id
        FROM faq_category
        WHERE 1 = 1';
    my $Ext = '';

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # search for name
    if ( defined $Param{Name} ) {

        # db like quote
        $Param{Name} = $DBObject->Quote( $Param{Name}, 'Like' );

        $Ext .= " AND name LIKE '%" . $Param{Name} . "%' $Self->{LikeEscapeString}";
    }

    # search for parent id
    if ( defined $Param{ParentID} ) {

        # db integer quote
        $Param{ParentID} = $DBObject->Quote( $Param{ParentID}, 'Integer' );

        $Ext .= ' AND parent_id = ' . $Param{ParentID};
    }

    # search for parent ids
    if (
        defined $Param{ParentIDs}
        && ref $Param{ParentIDs} eq 'ARRAY'
        && @{ $Param{ParentIDs} }
        )
    {

        # integer quote the parent ids
        for my $ParentID ( @{ $Param{ParentIDs} } ) {
            $ParentID = $DBObject->Quote( $ParentID, 'Integer' );
        }

        # create string
        my $InString = join ', ', @{ $Param{ParentIDs} };

        $Ext = ' AND parent_id IN (' . $InString . ')';
    }

    # search for category ids
    if (
        defined $Param{CategoryIDs}
        && ref $Param{CategoryIDs} eq 'ARRAY'
        && @{ $Param{CategoryIDs} }
        )
    {

        # integer quote the category ids
        for my $CategoryID ( @{ $Param{CategoryIDs} } ) {
            $CategoryID = $DBObject->Quote( $CategoryID, 'Integer' );
        }

        # create string
        my $InString = join ', ', @{ $Param{CategoryIDs} };

        $Ext = ' AND id IN (' . $InString . ')';
    }

    if (
        defined $Param{ValidIDs}
        && ref $Param{ValidIDs} eq 'ARRAY'
        && @{ $Param{ValidIDs} }
        )
    {
        # integer quote the valid ids
        for my $ValidID ( @{ $Param{ValidIDs} } ) {
            $ValidID = $DBObject->Quote( $ValidID, 'Integer' );
        }

        # create string
        my $InString = join ', ', @{ $Param{ValidIDs} };

        $Ext = ' AND valid_id IN (' . $InString . ')';
    }

    # ORDER BY
    if ( $Param{OrderBy} ) {
        $Ext .= " ORDER BY name";

        # set the default sort order
        $Param{SortBy} ||= 'up';

        # SORT
        if ( $Param{SortBy} ) {
            if ( $Param{SortBy} eq 'up' ) {
                $Ext .= " ASC";
            }
            elsif ( $Param{SortBy} eq 'down' ) {
                $Ext .= " DESC";
            }
        }
    }

    # SQL STATEMENT
    $SQL .= $Ext;

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Limit => $Param{Limit},
    );

    my @List;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @List, $Row[0];
    }

    return \@List;
}

=item CategorySubCategoryIDList()

get all subcategory ids of of a category

    my $SubCategoryIDArrayRef = $FAQObject->CategorySubCategoryIDList(
        ParentID     => 1,
        Mode         => 'Public', # (Agent, Customer, Public)
        Contact => 'tt',
        UserID       => 1,
    );

Returns:

    $SubCategoryIDArrayRef = [
        3,
        4,
        5,
        6,
    ];

=cut

sub CategorySubCategoryIDList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );

        return;
    }

    # check needed stuff
    if ( !defined $Param{ParentID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ParentID!',
        );

        return;
    }

    my $Categories = {};

    if ( $Param{Mode} && $Param{Mode} eq 'Agent' ) {

        # get agents categories
        $Categories = $Self->GetUserCategories(
            Type   => 'ro',
            UserID => $Param{UserID},
        );
    }
    elsif ( $Param{Mode} && $Param{Mode} eq 'Customer' ) {

        # get customer categories
        $Categories = $Self->GetCustomerCategories(
            Type         => 'ro',
            Contact => $Param{Contact},
            UserID       => $Param{UserID},
        );
    }
    else {

        # get all categories
        $Categories = $Self->CategoryList(
            Valid  => 1,
            UserID => $Param{UserID},
        );
    }

    my @SubCategoryIDs;
    my @TempSubCategoryIDs = keys %{ $Categories->{ $Param{ParentID} } };
    SUBCATEGORYID:
    while (@TempSubCategoryIDs) {

        # get next subcategory id
        my $SubCategoryID = shift @TempSubCategoryIDs;

        # add to result
        push @SubCategoryIDs, $SubCategoryID;

        # check if subcategory has own subcategories
        next SUBCATEGORYID if !$Categories->{$SubCategoryID};

        # add new subcategories
        push @TempSubCategoryIDs, keys %{ $Categories->{$SubCategoryID} };
    }

    # sort subcategories numerically
    @SubCategoryIDs = sort { $a <=> $b } @SubCategoryIDs;

    return \@SubCategoryIDs;
}

=item CategoryTreeList()

get all categories as tree (with their long names)

    my $CategoryTree = $FAQObject->CategoryTreeList(
        Valid  => 0,  # (0|1, optional)
        UserID => 1,
    );

Returns:

    $CategoryTree = {
        1 => 'Misc',
        2 => 'My Category',
        3 => 'My Category::Sub Category A',
        4 => 'My Category::Sub Category B',
    };

=cut

sub CategoryTreeList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );

        return;
    }

    # set default
    my $Valid = 0;
    if ( $Param{Valid} ) {
        $Valid = $Param{Valid};
    }

    # check if result is already cached
    my $CacheKey = "FAQ::CategoryTreeList::Valid::$Valid";
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # build SQL
    my $SQL = '
        SELECT id, parent_id, name
        FROM faq_category';

    # add where clause for valid categories
    if ($Valid) {
        $SQL .= ' WHERE valid_id IN ('
            . join ', ', $Kernel::OM->Get('Valid')->ValidIDsGet()
            . ')';
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # prepare SQL
    return if !$DBObject->Prepare(
        SQL => $SQL,
    );

    # fetch result
    my %CategoryMap;
    my %CategoryNameLookup;
    my %ParentIDLookup;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $CategoryMap{ $Row[1] }->{ $Row[0] } = $Row[2];
        $CategoryNameLookup{ $Row[0] }       = $Row[2];
        $ParentIDLookup{ $Row[0] }           = $Row[1];
    }

    # to store the category tree
    my %CategoryTree;

    # check all parent IDs
    for my $ParentID ( sort { $a <=> $b } keys %CategoryMap ) {

        # get subcategories and names for this parent id
        while ( my ( $CategoryID, $CategoryName ) = each %{ $CategoryMap{$ParentID} } ) {

            # lookup the parents name
            my $NewParentID = $ParentID;
            while ($NewParentID) {

                # pre-append parents category name
                if ( $CategoryNameLookup{$NewParentID} ) {
                    $CategoryName = $CategoryNameLookup{$NewParentID} . '::' . $CategoryName;
                }

                # get up one parent level
                $NewParentID = $ParentIDLookup{$NewParentID} || 0;
            }

            # add category to tree
            $CategoryTree{$CategoryID} = $CategoryName;
        }
    }

    # cache result
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%CategoryTree,
    );

    return \%CategoryTree;
}

=item CategoryUpdate()

update a category

    my $Success = $FAQObject->CategoryUpdate(
        CategoryID => 2,
        ParentID   => 1,
        Name       => 'Some Category',
        Comment    => 'some comment',
        UserID     => 1,
    );

Returns:

    $Success = 1;                # or undef if category could not be updated

=cut

sub CategoryUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Name UserID)) {
        if ( !$Param{$Argument} ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # check needed stuff
    for my $Argument (qw(CategoryID ParentID)) {
        if ( !defined $Param{$Argument} ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # check that ParentID is not an empty string but number 0 is allowed
    if ( $Param{ParentID} eq '' ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "ParentID cannot be empty!",
        );

        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # SQL
    return if !$DBObject->Do(
        SQL => '
            UPDATE faq_category
            SET parent_id = ?, name = ?, comments = ?, valid_id = ?, changed = current_timestamp,
                changed_by = ?
            WHERE id = ?',
        Bind => [
            \$Param{ParentID}, \$Param{Name},
            \$Param{Comment},  \$Param{ValidID},
            \$Param{UserID},   \$Param{CategoryID},
        ],
    );

    # log notice
    $Kernel::OM->Get('Log')->Log(
        Priority => 'notice',
        Message  => "FAQCategory: '$Param{Name}' "
            . "ID: '$Param{CategoryID}' updated successfully ($Param{UserID})!",
    );

    # clear cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'FAQ.Category',
        ObjectID  => $Param{CategoryID},
    );

    return 1;
}

=item AgentCategorySearch()

get the category search as array ref

    my $CategoryIDArrayRef = $FAQObject->AgentCategorySearch(
        ParentID => 3,   # (optional, default 0)
        UserID   => 1,
    );

Returns:

    $CategoryIDArrayRef = [
        '4',
        '8',
    ];

=cut

sub AgentCategorySearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );

        return;
    }

    # set default parent id
    if ( !defined $Param{ParentID} ) {
        $Param{ParentID} = 0;
    }
    my $Categories = $Self->GetUserCategories(
        Type   => 'ro',
        UserID => $Param{UserID},
    );

    my %Category = %{ $Categories->{ $Param{ParentID} } };
    my @CategoryIDs = sort { $Category{$a} cmp $Category{$b} } ( keys %Category );

    return \@CategoryIDs;
}

=item CustomerCategorySearch()

get the category search as hash

    my $CategoryIDArrayRef = @{$FAQObject->CustomerCategorySearch(
        Contact  => 'tt',
        ParentID      => 3,   # (optional, default 0)
        Mode          => 'Customer',
        UserID        => 1,
    )};

Returns:

    $CategoryIDArrayRef = [
        '4',
        '8',
    ];

=cut

sub CustomerCategorySearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Contact Mode UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # set default parent id
    if ( !defined $Param{ParentID} ) {
        $Param{ParentID} = 0;
    }

    my $Categories = $Self->GetCustomerCategories(
        Contact => $Param{Contact},
        Type         => 'ro',
        UserID       => $Param{UserID},
    );

    my %Category = %{ $Categories->{ $Param{ParentID} } };
    my @CategoryIDs = sort { $Category{$a} cmp $Category{$b} } ( keys %Category );

    my @AllowedCategoryIDs;
    my %Articles;

    # check cache
    my $CacheKey = 'CustomerCategorySearch::Articles';
    if ( $Self->{Cache}->{$CacheKey} ) {
        %Articles = %{ $Self->{Cache}->{$CacheKey} };
    }
    else {

        # build valid id string
        my $ValidIDsString = join ', ', $Kernel::OM->Get('Valid')->ValidIDsGet();

        my $SQL = "
            SELECT faq_item.id, faq_item.category_id
            FROM faq_item, faq_state_type, faq_state
            WHERE faq_state.id = faq_item.state_id
                AND faq_state.type_id = faq_state_type.id
                AND faq_state_type.name != 'internal'
                AND faq_item.valid_id IN ($ValidIDsString)
                AND faq_item.approved = 1";

        # get database object
        my $DBObject = $Kernel::OM->Get('DB');

        return if !$DBObject->Prepare(
            SQL => $SQL,
        );
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Articles{ $Row[1] }++;
        }
    }

    for my $CategoryID (@CategoryIDs) {

        # get all subcategory ids for this category
        my $SubCategoryIDs = $Self->CategorySubCategoryIDList(
            ParentID     => $CategoryID,
            Mode         => $Param{Mode},
            Contact => $Param{Contact},
            UserID       => $Param{UserID},
        );

        # add this category id
        my @IDs = ( $CategoryID, @{$SubCategoryIDs} );

        # check if category contains articles with state external or public
        ID:
        for my $ID (@IDs) {
            next ID if !$Articles{$ID};
            push @AllowedCategoryIDs, $CategoryID;
            last ID;
        }
    }

    return \@AllowedCategoryIDs;
}

=item PublicCategorySearch()

get the category search as hash

    my $CategoryIDArrayRef = $FAQObject->PublicCategorySearch(
        ParentID      => 3,   # (optional, default 0)
        Mode          => 'Public',
        UserID        => 1,
    );

Returns:

    $CategoryIDArrayRef = [
        '4',
        '8',
    ];

=cut

sub PublicCategorySearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Mode UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    if ( !defined $Param{ParentID} ) {
        $Param{ParentID} = 0;
    }

    my $CategoryListCategories = $Self->CategoryList(
        Valid  => 1,
        UserID => $Param{UserID},
    );

    return [] if !$CategoryListCategories->{ $Param{ParentID} };

    my %Category = %{ $CategoryListCategories->{ $Param{ParentID} } };
    my @CategoryIDs = sort { $Category{$a} cmp $Category{$b} } ( keys %Category );
    my @AllowedCategoryIDs;

    # build valid id string
    my $ValidIDsString = join ', ', $Kernel::OM->Get('Valid')->ValidIDsGet();

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    for my $CategoryID (@CategoryIDs) {

        # get all subcategory ids for this category
        my $SubCategoryIDs = $Self->CategorySubCategoryIDList(
            ParentID     => $CategoryID,
            Mode         => $Param{Mode},
            Contact => $Param{Contact},
            UserID       => $Param{UserID},
        );

        # add this category id
        my @IDs = ( $CategoryID, @{$SubCategoryIDs} );

        # check if category contains articles with state public
        my $FoundArticle = 0;

        my $SQL = "
            SELECT faq_item.id
            FROM faq_item, faq_state_type, faq_state
            WHERE faq_item.category_id = ?
                AND faq_item.valid_id IN ($ValidIDsString)
                AND faq_state.id = faq_item.state_id
                AND faq_state.type_id = faq_state_type.id
                AND faq_state_type.name = 'public'
                AND faq_item.approved = 1";

        ID:
        for my $ID (@IDs) {

            return if !$DBObject->Prepare(
                SQL   => $SQL,
                Bind  => [ \$ID ],
                Limit => 1,
            );
            while ( my @Row = $DBObject->FetchrowArray() ) {
                $FoundArticle = $Row[0];
            }
            last ID if $FoundArticle;
        }

        # an article was found
        if ($FoundArticle) {
            push @AllowedCategoryIDs, $CategoryID;
        }
    }

    return \@AllowedCategoryIDs;

}

=item GetPublicCategoriesLongNames()

get public category-groups (show category long names)

    my $PublicCategoryGroupHashRef = $FAQObject->GetPublicCategoriesLongNames(
        Type   => 'rw',
        UserID => 1,
    );

Returns:

    $PublicCategoryGroupHashRef = {
        1 => 'Misc',
        2 => 'My Category',
        3 => 'My Category::Sub Category A',
        4 => 'My Category::Sub Category A',
    };

=cut

sub GetPublicCategoriesLongNames {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # get all categories
    my $PublicCategories = $Self->CategoryList( UserID => $Param{UserID} );

    # extract category ids
    my %AllCategoryIDs;
    for my $ParentID ( sort keys %{$PublicCategories} ) {
        for my $CategoryID ( sort keys %{ $PublicCategories->{$ParentID} } ) {
            $AllCategoryIDs{$CategoryID} = 1;
        }
    }

    # get all public category ids
    my @PublicCategoryIDs;
    for my $CategoryID ( 0, keys %AllCategoryIDs ) {
        push @PublicCategoryIDs, @{
            $Self->PublicCategorySearch(
                ParentID => $CategoryID,
                Mode     => 'Public',
                UserID   => $Param{UserID},
                )
        };
    }

    # build public category hash
    $PublicCategories = {};
    for my $CategoryID (@PublicCategoryIDs) {
        my %Category = $Self->CategoryGet(
            CategoryID => $CategoryID,
            UserID     => $Param{UserID},
        );
        $PublicCategories->{ $Category{ParentID} }->{ $Category{CategoryID} } = $Category{Name};
    }

    # get all categories with their long names
    my $CategoryTree = $Self->CategoryTreeList(
        Valid  => 1,
        UserID => $Param{UserID},
    );

    # to store the user categories with their long names
    my %PublicCategoriesLongNames;

    # get the long names of the categories where user has rights
    PARENTID:
    for my $ParentID ( sort keys %{$PublicCategories} ) {

        next PARENTID if !$PublicCategories->{$ParentID};
        next PARENTID if ref $PublicCategories->{$ParentID} ne 'HASH';
        next PARENTID if !%{ $PublicCategories->{$ParentID} };

        for my $CategoryID ( sort keys %{ $PublicCategories->{$ParentID} } ) {
            $PublicCategoriesLongNames{$CategoryID} = $CategoryTree->{$CategoryID};
        }
    }

    return \%PublicCategoriesLongNames;
}

=item CheckCategoryUserPermission()

get user permission for a category

    my $PermissionString = $FAQObject->CheckCategoryUserPermission(
        CategoryID => '123',
        UserID     => 1,
    );

Returns:

    $PermissionString = 'rw';               # or 'ro' or ''

=cut

sub CheckCategoryUserPermission {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(CategoryID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    my $UserCategories = $Self->GetUserCategories(
        Type   => 'ro',
        UserID => $Param{UserID},
    );

    for my $Permission (qw(rw ro)) {
        for my $ParentID ( sort keys %{$UserCategories} ) {
            my $Categories = $UserCategories->{$ParentID};
            for my $CategoryID ( sort keys %{$Categories} ) {
                if ( $CategoryID == $Param{CategoryID} ) {

                    return $Permission;
                }
            }
        }
    }

    return '';
}

=item CheckCategoryCustomerPermission()

get customer user permission for a category

    my $PermissionString $FAQObject->CheckCategoryCustomerPermission(
        Contact => 'mm',
        CategoryID   => '123',
        UserID       => 1,
    );

Returns:

    $PermissionString = 'rw';               # or 'ro' or ''

=cut

sub CheckCategoryCustomerPermission {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Contact CategoryID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    for my $Permission (qw(rw ro)) {
        my $CustomerCategories = $Self->GetCustomerCategories(
            Contact => $Param{Contact},
            Type         => 'ro',
            UserID       => $Param{UserID},
        );
        for my $ParentID ( sort keys %{$CustomerCategories} ) {
            my $Categories = $CustomerCategories->{$ParentID};
            for my $CategoryID ( sort keys %{$Categories} ) {
                if ( $CategoryID == $Param{CategoryID} ) {

                    return $Permission;
                }
            }
        }
    }

    return '';
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
