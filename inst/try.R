library(openalexR)
library(httr2)

query <- oa_query(
  entity = "works",
  search = "toast AND biodiversity"
)

req <- request(query)

resp <- req |> 
  req_perform()

resp |> resp_body_string() |> writeLines("test.json")

