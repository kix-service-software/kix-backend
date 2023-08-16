Feature: GET request to the /system/dynamicfields/types resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get a collection of existing dynamicfield types
    When I get a collection of dynamicfield types
    Then the response code is 200
    Then the response contains 8 items of type "DynamicFieldType"
    And the response contains the following items of type DynamicFieldType
      | Name                      | DisplayName               |
      | CheckList                 | Checklist                 |
      | Date                      | Date                      |
      | DateTime                  | Date / Time               |
      | ITSMConfigItemReference   | AssetReference            |
      | Multiselect               | Selection                 |
      | Table                     | Table                     |
      | Text                      | Text                      |
      | TextArea                  | Textarea                  |

