---@class HttpRequest
---@field url string The full URL to request
---@field method? string The HTTP verb, defaults to `GET`
---@field token? string GitHub access token, sent as a Bearer credential
---@field body? table Encoded as JSON and sent as the request body

---@class HttpResponse
---@field status number The HTTP status code
---@field body table|nil The decoded JSON body, or `nil` if the body was not JSON
---@field raw string The undecoded response body
