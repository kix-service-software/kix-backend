 Feature: GET request to the /system/objecticons resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing objecticons  
    When I query the collection of objecticons  
    Then the response code is 200
#    And the response object is ObjectIconCollectionResponse

  Scenario: get the list of existing objecticons with filter (+)
    When I query the collection of objecticons with filter
    Then the response code is 200
    And the response contains 1 items of type "ObjectIcon"
    And the response contains the following items of type ObjectIcon
      | Object   | ContentType   |
      | MIMEType | image/svg+xml |



