#!perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

########################################################################################################
# Given
########################################################################################################

Given qr/a permission for RoleID (\d+) with$/, sub {
   my %Properties;
   foreach my $Row ( @{ C->data } ) {
      foreach my $Attribute ( keys %{$Row}) {
         $Properties{$Attribute} = $Row->{$Attribute};
      }
   }

   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/roles/'.$1.'/permissions',
      Token   => S->{Token},
      Content => {
         Permission => {
            %Properties
         }
      }
   );
};

########################################################################################################
# When
########################################################################################################


########################################################################################################
# Then
########################################################################################################


1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
