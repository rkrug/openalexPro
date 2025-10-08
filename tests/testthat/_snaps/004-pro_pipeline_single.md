# pro_request_jsonl_parquet single identifier

    Code
      x <- read_corpus(output_parquet, return_data = FALSE)
      nrow(x)
    Output
      [1] 1
    Code
      sort(names(x))
    Output
       [1] "apc_list"                       "apc_paid"                      
       [3] "authorships"                    "best_oa_location"              
       [5] "biblio"                         "citation"                      
       [7] "citation_normalized_percentile" "cited_by_api_url"              
       [9] "cited_by_count"                 "cited_by_percentile_year"      
      [11] "concepts"                       "corresponding_author_ids"      
      [13] "corresponding_institution_ids"  "countries_distinct_count"      
      [15] "counts_by_year"                 "created_date"                  
      [17] "datasets"                       "display_name"                  
      [19] "doi"                            "fulltext_origin"               
      [21] "fwci"                           "grants"                        
      [23] "has_fulltext"                   "id"                            
      [25] "ids"                            "indexed_in"                    
      [27] "institution_assertions"         "institutions_distinct_count"   
      [29] "is_paratext"                    "is_retracted"                  
      [31] "keywords"                       "language"                      
      [33] "locations"                      "locations_count"               
      [35] "mesh"                           "open_access"                   
      [37] "page"                           "primary_location"              
      [39] "primary_topic"                  "publication_date"              
      [41] "publication_year"               "referenced_works"              
      [43] "referenced_works_count"         "related_works"                 
      [45] "sustainable_development_goals"  "title"                         
      [47] "topics"                         "type"                          
      [49] "type_crossref"                  "updated_date"                  
      [51] "versions"                      

