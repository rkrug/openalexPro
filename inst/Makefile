SNAPSHOTDIR="./openalex-snapshot"
ARROWDIR="./arrow"

all: clean snapshot arrow

snapshot_info:
	aws s3 ls --summarize --human-readable --no-sign-request --recursive "s3://openalex/"

snapshot:
	aws s3 sync --delete "s3://openalex" "'${SNAPSHOTDIR}'" --no-sign-request

arrow: clean_arrow
	Rscript \
	-e 'library(openalexPro)' \
	-e 'openalexPro::snapshot_to_parquet(snapshot_dir = "'${SNAPSHOTDIR}'", arrow_dir = "'${ARROWDIR}'")'

clean_arrow:
	rm -rf ${ARROWDIR}

clean_snapshot:
	rm -rf ${SNAPSHOTDIR}

clean: clean_arrow clean_snapshot

.PHONY: snapshot arrow clean clean_arrow clean_snapshot
