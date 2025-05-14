# pro_request_jsonl_parquet search `biodiversity AND toast`

    Code
      x <- read_corpus(output_parquet, return_data = FALSE)
      nrow(x)
    Output
      [1] 8
    Code
      sort(names(x))
    Output
       [1] "abstract"                       "abstract_inverted_index_v3"    
       [3] "apc_list"                       "apc_paid"                      
       [5] "authorships"                    "best_oa_location"              
       [7] "biblio"                         "citation"                      
       [9] "citation_normalized_percentile" "cited_by_api_url"              
      [11] "cited_by_count"                 "cited_by_percentile_year"      
      [13] "concepts"                       "corresponding_author_ids"      
      [15] "corresponding_institution_ids"  "countries_distinct_count"      
      [17] "counts_by_year"                 "created_date"                  
      [19] "datasets"                       "display_name"                  
      [21] "doi"                            "fulltext_origin"               
      [23] "fwci"                           "grants"                        
      [25] "has_fulltext"                   "id"                            
      [27] "ids"                            "indexed_in"                    
      [29] "institution_assertions"         "institutions_distinct_count"   
      [31] "is_paratext"                    "is_retracted"                  
      [33] "keywords"                       "language"                      
      [35] "locations"                      "locations_count"               
      [37] "mesh"                           "open_access"                   
      [39] "page"                           "primary_location"              
      [41] "primary_topic"                  "publication_date"              
      [43] "publication_year"               "referenced_works"              
      [45] "referenced_works_count"         "related_works"                 
      [47] "relevance_score"                "sustainable_development_goals" 
      [49] "title"                          "topics"                        
      [51] "type"                           "type_crossref"                 
      [53] "updated_date"                   "versions"                      

