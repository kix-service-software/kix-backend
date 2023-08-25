# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

%Config = (
   Search => {

       # tickets created in the last 120 minutes
       TicketID => 1,
   },

# Declaration of thresholds
# min_warn_treshold > Number of tickets -> WARNING
# max_warn_treshold < Number of tickets -> WARNING
# min_crit_treshold > Number of tickets -> ALARM
# max_warn_treshold < Number of tickets -> ALARM

   min_warn_treshold => 0,
   max_warn_treshold => 10,
   min_crit_treshold => 0,
   max_crit_treshold => 20,

# Information used by Nagios
# Name of check shown in Nagios Status Information
   checkname => 'KIX Checker',

# Text shown in Status Information if everything is OK
   OK_TXT    => 'number of tickets:',

# Text shown in Status Information if warning threshold reached
   WARN_TXT  => 'number of tickets:',

# Text shown in Status Information if critical threshold reached
   CRIT_TXT  => 'critical number of tickets:',

);


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
