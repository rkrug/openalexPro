# pro_request_jsonl_parquet single identifier

    Code
      x <- read_corpus(output_parquet, return_data = FALSE)
      nrow(x)
    Output
      [1] 1
    Code
      sort(names(x))
    Output
       [1] "abstract_inverted_index_v3"     "apc_list"                      
       [3] "apc_paid"                       "authorships"                   
       [5] "best_oa_location"               "biblio"                        
       [7] "citation"                       "citation_normalized_percentile"
       [9] "cited_by_api_url"               "cited_by_count"                
      [11] "cited_by_percentile_year"       "concepts"                      
      [13] "corresponding_author_ids"       "corresponding_institution_ids" 
      [15] "countries_distinct_count"       "counts_by_year"                
      [17] "created_date"                   "datasets"                      
      [19] "display_name"                   "doi"                           
      [21] "fulltext_origin"                "fwci"                          
      [23] "grants"                         "has_fulltext"                  
      [25] "id"                             "ids"                           
      [27] "indexed_in"                     "institution_assertions"        
      [29] "institutions_distinct_count"    "is_paratext"                   
      [31] "is_retracted"                   "keywords"                      
      [33] "language"                       "locations"                     
      [35] "locations_count"                "mesh"                          
      [37] "open_access"                    "page"                          
      [39] "primary_location"               "primary_topic"                 
      [41] "publication_date"               "publication_year"              
      [43] "referenced_works"               "referenced_works_count"        
      [45] "related_works"                  "sustainable_development_goals" 
      [47] "title"                          "topics"                        
      [49] "type"                           "type_crossref"                 
      [51] "updated_date"                   "versions"                      

