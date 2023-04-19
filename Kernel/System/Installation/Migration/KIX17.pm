# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17;

use strict;
use warnings;

use List::Util qw(uniq);
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Installation::Migration::KIX17::Common
);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    foreach ( qw(Async MigrationID Source SourceID) ) {
        $Self->{$_} = $Param{$_};
    }

    # handle given options
    if ( $Param{Options} ) {
        $Self->ParseOptions(Options => $Param{Options});
    }

    # get all object handler modules
    my $ObjectHandlers = $Kernel::OM->Get('Config')->Get('Migration::Source::KIX17');
    if ( !IsHashRefWithData($ObjectHandlers) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No object handlers available!',
        );
        return;
    }

    # prepare filter if given
    my %Filter;
    if ( IsArrayRefWithData($Param{Filter}) ) {
        foreach my $FilterItem ( @{$Param{Filter}} ) {
            next if $FilterItem !~ /^(.*?)\{(.*?)\}$/g;
            $Filter{$1} = $2;
        }
    }

    # register each handler for every supported object
    foreach my $Handler ( keys %{$ObjectHandlers} ) {
        $Kernel::OM->ObjectParamAdd(
            $ObjectHandlers->{$Handler}->{Module} => {
                %{$Self},
                Config => $ObjectHandlers->{$Handler},
            }
        );
        my $HandlerObject = $Kernel::OM->Get(
            $ObjectHandlers->{$Handler}->{Module}
        );
        if ( !$HandlerObject ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to load handler backend for $Handler!",
            );
            next;
        }
        my $Description = $HandlerObject->Describe();
        if ( !IsHashRefWithData($Description) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Handler backend for $Handler doesn't describe itself!",
            );
            next;
        }
        if ( !IsArrayRefWithData($Description->{Supports}) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Handler backend for $Handler doesn't define any supported objects!",
            );
            next;
        }
        foreach my $Supports ( sort @{$Description->{Supports}} ) {
            $HandlerObject->{Source} = 'KIX17';
            $Self->{Handler}->{$Supports} = $HandlerObject;

            if ( $Filter{$Supports} ) {
                $HandlerObject->SetFilter(
                    Type   => $Supports,
                    Filter => $Filter{$Supports}
                );
            }

            if ( IsHashRefWithData($Param{Mapping}) && IsHashRefWithData($Param{Mapping}->{$Supports}) ) {
                $HandlerObject->SetMapping(
                    Type    => $Supports,
                    Mapping => $Param{Mapping}->{$Supports}
                );
            }
        }
    }

    return $Self;
}

=item ObjectTypeList()

return the list (array) of supported object types

=cut

sub ObjectTypeList {
    my ( $Self, %Param ) = @_;

    return sort keys %{$Self->{Handler}};
}

=item Run()

run the migration

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    STDOUT->autoflush(1);

    my @Types = keys %{$Self->{Handler}};
    if ( $Param{ObjectType} ) {
        my @SelectedTypes;
        foreach my $Type ( split(/,/, $Param{ObjectType}) ) {
            $Type =~ s/\*/.*?/g;
            my @Tmp = grep /^$Type$/g, @Types;
            if ( !@Tmp ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Type \"$Type\" not supported!"
                );
                return;
            }
            @SelectedTypes = (
                @SelectedTypes,
                @Tmp
            );
        }
        @Types = @SelectedTypes;
    }

    # get correct type order for import with respect to dependencies
    my %DepCount;
    my %AllDeps;
    foreach my $Type ( @Types ) {
        $DepCount{$Type} = $Self->_GetDependencyCount(
            Type    => $Type,
            AllDeps => \%AllDeps,
        );
    }
    @Types = sort { $DepCount{$a} <=> $DepCount{$b} } keys %DepCount;

    my @MissingDeps = grep { !exists $DepCount{$_} } sort keys %AllDeps;
    if ( @MissingDeps ) {
        if ( !$Self->{Options}->{AutoDeps} ) {
            print "the following depending types are missing: " . join(', ', @MissingDeps) . ".\nIt's recommended to include those types. Also you can use the auto-deps option.\n\n";
        }
        else {
            print "automatically adding missing dependencies: " . join(', ', @MissingDeps) . "\n\n";

            # get correct type order for import with respect to dependencies
            my %DepCount;
            foreach my $Type ( ( @Types, @MissingDeps ) ) {
                $DepCount{$Type} = $Self->_GetDependencyCount(
                    Type => $Type,
                );
            }
            @Types = sort { $DepCount{$a} <=> $DepCount{$b} } keys %DepCount;
        }
    }

    print "importing types in the following order: " . join(', ', @Types) . "\n";

    # get the prepared meta data and update it
    my $MigrationState = $Self->_GetMigrationState();
    $MigrationState->{ParsedOptions} = $Self->{Options};
    $MigrationState->{Status} = Kernel::Language::Translatable('in progress');
    $MigrationState->{StartTime} = Time::HiRes::time();
    $MigrationState->{State}->{Types}  = \@Types;
    $Self->_UpdateMigrationState($MigrationState);

    foreach my $Type (@Types) {
        my $ItemCount = $Self->{Handler}->{$Type}->Count(
            Type => $Type,
        );
        $Self->{Handler}->{$Type}->InitProgress(Type => $Type, ItemCount => $ItemCount);
    }

    TYPE:
    foreach my $Type ( @Types ) {
        my $MigrationState = $Self->_GetMigrationState();

        # abort if we don't have a state
        last if $MigrationState->{Status} eq 'aborting';

        my $StartTime = Time::HiRes::time();

        $MigrationState->{State}->{TypeInProgress} = $Type;
        $MigrationState->{State}->{Progress}->{$Type}->{StartTime} = $StartTime;
        $Self->_UpdateMigrationState($MigrationState);

        if ( $MigrationState->{State}->{Progress}->{$Type}->{ItemCount} > 0 ) {
            $Self->{Handler}->{$Type}->SetWorkers(Workers => $Param{Workers} || 1);

            my $Result = $Self->{Handler}->{$Type}->Run(
                Type => $Type,
            );
        }
        $Self->{Handler}->{$Type}->StopProgress($Type);
    }

    # get the prepared meta data and update it
    my $MigrationState = $Self->_GetMigrationState();
    $MigrationState->{Status} = $MigrationState->{Status} ne 'aborting' ? 'finished' : 'aborted';
    $MigrationState->{EndTime} = Time::HiRes::time();
    $Self->_UpdateMigrationState($MigrationState);

    return 1;
}

=item Count()

count the objects

=cut

sub Count {
    my ( $Self, %Param ) = @_;

    my @Types = keys %{$Self->{Handler}};
    if ( $Param{ObjectType} ) {
        my @SelectedTypes;
        foreach my $Type ( split(/,/, $Param{ObjectType}) ) {
            $Type =~ s/\*/.*?/g;
            my @Tmp = grep /^$Type$/g, @Types;
            if ( !@Tmp ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Type \"$Type\" not supported!"
                );
                return;
            }
            @SelectedTypes = (
                @SelectedTypes,
                @Tmp
            );
        }
        @Types = @SelectedTypes;
    }

    my %Result;
    foreach my $Type ( @Types ) {
        $Result{$Type} = $Self->{Handler}->{$Type}->Count(
            Type => $Type,
        );
    }

    return %Result;
}

sub _GetDependencyCount {
    my ( $Self, %Param ) = @_;
    my %Result;

    return if !$Param{Type};

    my $DepCount = 0;
    my $Type     = $Param{Type};

    return 0 if !$Self->{Handler}->{$Type} || !$Self->{Handler}->{$Type}->can('Describe');
    return 0 if !IsHashRefWithData($Self->{Handler}->{$Type}->Describe()->{Depends}) && !IsArrayRefWithData($Self->{Handler}->{$Type}->Describe()->{DependsOnType});

    # get dependencies of type
    my @Deps = (
        ( uniq sort @{$Self->{Handler}->{$Type}->Describe()->{DependsOnType} || []} ),
        ( uniq sort values %{$Self->{Handler}->{$Type}->Describe()->{Depends} || {}} ),
    );
    if ( IsArrayRefWithData(\@Deps) ) {
        # check for wildcards
        if ( grep(/\*/, @Deps) ) {
            my %Handlers = %{$Self->{Handlers}};
            delete $Handlers{$Type};
            my @Deps = (
                @Deps,
                keys %Handlers,
            );
        }

        # check each dependency in depth
        foreach my $Dep ( @Deps ) {
            # add dependency to result hash
            $Param{AllDeps}->{$Dep} = 1 if exists $Param{AllDeps};

            $DepCount++;
            my $SubCount = $Self->_GetDependencyCount(
                %Param,
                Type => $Dep,
            );
            $DepCount += $SubCount;
        }
    }

    return $DepCount;
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
