 Feature: GET request to the /system/users resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing users 
    When I query the collection of users
    Then the response code is 200
    And the response object is UserCollectionResponse

  Scenario: get the list of existing users with filter
    Given 8 of users
    When I query the collection of users with filter of UserEmail "admin"
    Then the response code is 200
    And the response contains the following items of type User
      | UserEmail       | UserLogin |
      | admin@localhost | admin     |
      
  Scenario: get the list of existing users filtered is not an in
    Given 8 of users
    When I query the collection of users with AND-filter of UserEmail "admi" and UserIDs and UserFirstname "M"
    Then the response code is 200
    And the response contains the following items of type User
      | UserEmail       | UserLogin |
      | admin@localhost | admin     |

  Scenario: get the list of existing users with limit
    Given 8 of users
    When I query the collection of users with a limit of 4
    Then the response code is 200
    And the response contains 4 items of type "User"

