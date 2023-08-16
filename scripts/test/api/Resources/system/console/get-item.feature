 Feature: GET request to the /system/console/{consoleCommand} resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing console command
    When I get this console command "Maint::Cache::Delete"
    Then the response code is 200
#    And the response object is ConsoleCommandResponse

  Scenario: get an existing console command as root
    When I get this console command "Maint::Cache::Delete"
    Then the response code is 200
 #    And the response object is ConsoleCommandResponse
#    And the response contains the following items of type ConsoleCommand
#      | ExitCode | Output                                                                                                                                                                                                                                                       |
#      | 1        | Maint::Cache::Delete   :$VAR1 = {\n  'Command' => 'Maint::Cache::Delete'\n};\nError: You cannot run kix.Console.pl as root. Please run it as the apache user or with the help of su:\n  su -c \"bin/kix.Console.pl MyCommand\" -s /bin/bash <apache user> \n |

   Scenario: get an existing console command --allow-root
     When I get this console command "Maint::Cache::Delete"
     Then the response code is 200
#    And the response object is ConsoleCommandResponse
     And the response contains the following items type of ConsoleCommand
      | Command                                | Description                         |
      | Console::Command::Maint::Cache::Delete | Deletes cache items created by KIX. |