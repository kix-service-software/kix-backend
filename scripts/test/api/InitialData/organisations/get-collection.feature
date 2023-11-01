 Feature: GET request to the /organisations resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as Agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing organisations
    When I query the collection of organisations
    Then the response code is 200
    And the response contains the following items of type Organisation
      | Number  | Name            |
      | MY_ORGA | My Organisation |

  Scenario: get the list of existing organisations dynamicfield
    When I query the collection of organisations with df
    Then the DynamicField attributes are
      | DisplayValue     | DisplayValueShort |
      | Service Provider | Service Provider  |
