Feature: GET request to the /cmdb/configitems/:ConfigItemID/history/:HistoryID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing history
    Given a configitem
    Then the response code is 201
    When I query the cmdb collection of configitem historys 1
    Then the response code is 200
    When I get this configitem history 1
    Then the response code is 200
#    And the response object is ConfigItemHistoryResponse
    And the attribute "ConfigItemHistory.HistoryType" is "ConfigItemCreate"
    When I delete this configitem
    Then the response code is 204
    And the response has no content



    
