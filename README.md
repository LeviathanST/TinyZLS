This is just a simplified version of ZLS with for learning purposes.

# TODO
* Basic transport (via stdio).
  - [x] Write message.
  - [x] Read message.
* Deserialize and serialize data with JSON-RPC format. 
  - [x] Request.
  - [x] Response.
  - [x] Notification.
* LSP features:
  - [ ] Basic lifecycle:
    - [x] 1: Receive a initialization request from client and return a response result.
      - **NOTE:** Haven't procced any client request params and returned a static response result to make this stage minimal.
    - [x] 2: Receive a intialized notification from client and not response anything.
    - [ ] 3: Receive a shutdown request from client and response result.
    - [ ] 3: Receive a exit notification from client and not response anything.
