 Feature: GET request to the /system/console resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing console command
    When I query the collection of console
#    Then the response content
    Then the response code is 200
#    And the response object is ConsoleCommandCollectionResponse

  Scenario: get the list of existing console command filter
    When I query the collection of console with filter command "Console::Command::Maint::Ticket::UnlockTicket"
    Then the response code is 200
    And the response contains the following items type of ConsoleCommand
      | Command                                       | Description                      |
      | Console::Command::Maint::Ticket::UnlockTicket | Unlock a single ticket by force. |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Maint::Ticket::UnlockTimeout"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                        | Description                                        |
       | Console::Command::Maint::Ticket::UnlockTimeout | Unlock tickets that are past their unlock timeout. |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::Article::StorageSwitch"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                         | Description                                                                            |
       | Console::Command::Admin::Article::StorageSwitch | Migrate article attachment metadata files to DB. Leave attachment content files in FS. |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::Contact::Add"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                               | Description    |
       | Console::Command::Admin::Contact::Add | Add a contact. |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::Contact::List"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                | Description    |
       | Console::Command::Admin::Contact::List | List contacts. |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::FAQ::Import"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                              | Description      |
       | Console::Command::Admin::FAQ::Import | FAQ import tool. |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::ITSM::Configitem::Delete"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                           | Description                                                              |
       | Console::Command::Admin::ITSM::Configitem::Delete | Delete config items (all, by class (and deployment state) or by number). |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::ITSM::Configitem::ListDuplicates"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                                   | Description                                    |
       | Console::Command::Admin::ITSM::Configitem::ListDuplicates | List ConfigItems which have a non-unique name. |


   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::ITSM::ImportExport::AutoCreateMapping"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                                        | Description                                                            |
       | Console::Command::Admin::ITSM::ImportExport::AutoCreateMapping | The tool to automatic create a CSV-mapping for ITSM class definitions. |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::ITSM::ImportExport::Export"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                             | Description                         |
       | Console::Command::Admin::ITSM::ImportExport::Export | The tool for exporting config items |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::ITSM::IncidentState::Recalculate"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                                   | Description                                      |
       | Console::Command::Admin::ITSM::IncidentState::Recalculate | Recalculates the incident state of config items. |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::ImportExport::ListMappings"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                             | Description                               |
       | Console::Command::Admin::ImportExport::ListMappings | Lists available config item csv mappings. |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::Installation::GenerateAPIWebServiceDefinition"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                                                | Description                                                        |
       | Console::Command::Admin::Installation::GenerateAPIWebServiceDefinition | Generate a web service definition file for the application REST API |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::Installation::ListPlugins"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                            | Description   |
       | Console::Command::Admin::Installation::ListPlugins | List Plugins. |

   Scenario: get the list of existing console command filter
     When I query the collection of console with filter command "Console::Command::Admin::Installation::Migrate::CountObjects"
     Then the response code is 200
     And the response contains the following items type of ConsoleCommand
       | Command                                                      | Description                                                    |
       | Console::Command::Admin::Installation::Migrate::CountObjects | Count the number of supported objects typed from another tool. |



