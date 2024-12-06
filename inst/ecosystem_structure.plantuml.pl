@startuml openalexPro_ecosystem
cloud OpenAlex

folder "Local OpenAlex Data" as OpenAlex_snapshot {
    database "OpenAlex Snapshot\n----\nJSON" as json_snapshot #yellow
    database "OpenAlex Snapshot\n----\nParquet\n---\n**Partitioned**:\nid_block" as parquet_snapshot #yellow
}

database "Corpus with Search Results\n----\nParquet\n---\n**Partitioned**:\nid_block" as corpus_search #yellow
database "IDs from Search\n----\nrds\n---\ncharcter vector" as corpus_search_ids #yellow

action "Download Data Snapshot" as download_snapshot

action "Keyword Search on openalex\nretrieve only ids\n----\n**Use e.g.:**\n- ""openalexR::fetch()""\n- ""openalexPro::pro_request()""\n- ..." as keyword_openalex_ids
' action "snowball Search on openalex\n----\n**Use e.g.:**\n- ""openalexR::snowball()""\n- ""openalexPro::pro_snowball()""\n- ..." as search_openalex_ids

package "openalexPro" as openalexPro {
    action "Convert to Parquet\n----\n""snapshot_to_parquet()""\n----\n**Optional**:\ndecode abstract?\ncreate citation?" as snapshot_to_parquet
    action "Calculate id blocks ids\n----\n""id_blocks()""\n----\n" as id_block
    action "Filter ids\n----\n""filter_ids_from_snapshot()""\n----\n**Optional**:\ndecode abstract?\ncreate citation?" as filter_ids_from_snapshot
}

package "openalexPlot" as openalexPlot {
    action "Plot functions\n----\n""...()""\n----\n**Optional**:\nDetails to be decided" as plot_function
}


package "openalexNet" as openalexNet {
    action "Network analysis and plot functions functions\n----\n""...()""\n----\n**Optional**:\nDetails to be decided" as net_function
}


folder "Output" as output {
    artifact "Figures" as figures  #lime
    artifact "Analysis Results" as results #Lime
}

'  Download and convert data

OpenAlex --> download_snapshot
download_snapshot --> json_snapshot
json_snapshot --> snapshot_to_parquet
snapshot_to_parquet --> parquet_snapshot
parquet_snapshot --> filter_ids_from_snapshot
filter_ids_from_snapshot --> corpus_search

'  Filter by ids
OpenAlex --> keyword_openalex_ids
keyword_openalex_ids --> corpus_search_ids
corpus_search_ids --> id_block
id_block --> filter_ids_from_snapshot

'  plot
filter_ids_from_snapshot --> plot_function
plot_function --> figures

'  analyse
filter_ids_from_snapshot --> net_function
net_function --> results


newpage

action action
actor actor
actor/ "actor/"
agent agent
artifact artifact
boundary boundary
card card
circle circle
cloud cloud
collections collections
component component
control control
database database
entity entity
file file
folder folder
frame frame
hexagon hexagon
interface interface
label label
node node
package package
person person
process process
queue queue
rectangle rectangle
stack stack
storage storage
usecase usecase
usecase/ "usecase/"
@enduml