 Feature: GET request to the /system/users resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

Scenario: check is the existing users are consistent with the delivery defaults
    When I query the collection of users
    Then the response code is 200
#    And the response object is UserCollectionResponse
    And the response contains 1 items of type "User"
    And the response contains the following items of type User
      | UserFirstname | UserLastname | UserLogin | ValidID |
      | not           | assigned     | admin     | 1       |


