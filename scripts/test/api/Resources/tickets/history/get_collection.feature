Feature: GET request to the /tickets/:TicketID/history resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"      

  Scenario: get a collection of existing ticket history
    Given a ticket
    Given a article
    When I get a collection of ticket history
    Then the response code is 200
    When I delete this ticket
    Then the response code is 204
    And the response has no content 





    
