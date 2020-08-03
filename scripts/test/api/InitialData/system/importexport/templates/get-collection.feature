 Feature: GET request to the /system/importexport/templates resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing importexport templates
    When I query the collection of importexport templates 
    Then the response code is 200
    Then the response contains 8 items of type "ImportExportTemplate"
    And the response contains the following items of type ImportExportTemplate
      | Name                        | Object         | Format |
      | Building (auto-created map) | ITSMConfigItem | CSV    |
      | Computer (auto-created map) | ITSMConfigItem | CSV    |
      | Hardware (auto-created map) | ITSMConfigItem | CSV    |
      | Location (auto-created map) | ITSMConfigItem | CSV    |
      | Network (auto-created map)  | ITSMConfigItem | CSV    |
      | Room (auto-created map)     | ITSMConfigItem | CSV    |
      | Service (auto-created map)  | ITSMConfigItem | CSV    |
      | Software (auto-created map) | ITSMConfigItem | CSV    |



