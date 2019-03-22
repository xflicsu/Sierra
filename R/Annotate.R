#########################################################################################################
## annotate_gr_from_gtf
##
## Annotates a granges object with overlapping genes from gtf file.
##
##  gr is the genomic ranges that need to be annotation. Ideally original input should be in the format:
##       chr1:1234-2345:+    # chr:start-end:strand
##   This could already exist within an R object or you can copy it in via readClipboard. 
##
##  gr <- GRanges(readClipboard())
##
## You need to run the following code:
##         gtf_file <- "u:/Reference/hg38/hg38_gene.gtf.gz"
##        gtf_gr <- rtracklayer::import(gtf_file)
##        gtf_TxDb <- GenomicFeatures::makeTxDbFromGFF(gtf_file, format="gtf")
##
## annotationType can be c("any", "start", "end", "within", "equal"),
## Returns a dataframe
##
## Written March 2019
annotate_gr_from_gtf <- function(gr, invert_strand = FALSE, gtf_gr = NULL,
                       annotationType ="within",
                       transcriptDetails = FALSE, gtf_TxDb)
{
  if (is.null(gtf_gr))
  {warning("No gtf file provided")
    return(NULL)
  }

  if (invert_strand)
  { gr <- invertStrand(gr) }

#  mcols(gtf_gr) <- mcols(gtf_gr)[c("type","gene_id","gene_type","gene_name")]
  mcols(gtf_gr) <- mcols(gtf_gr)[c("type","gene_id","gene_name")]
  my_genes <- gtf_gr[gtf_gr$type == "gene"]


  all_hits <- findOverlaps(gr , my_genes, type= annotationType)
  identified_gene_symbols <- my_genes[subjectHits(all_hits)]$gene_name

  idx_to_annotate <- queryHits(all_hits)
  multi_annotations <- which(table(idx_to_annotate) > 1)
  unique_annotations <- unique(idx_to_annotate)

  test <- unlist(sapply(multi_annotations,FUN=function(x) {
    newID <- paste(identified_gene_symbols[which(x== idx_to_annotate)],collapse=",")
   # rep(newID, length(which(x== idx_to_annotate)))
    }))
  multi_idx <- as.numeric(names(test))  # These are the indexes to annotate


  df <- as.data.frame(gr)
  df$gene_id <- ""
  df$gene_id[idx_to_annotate] <- identified_gene_symbols
  df$gene_id[multi_idx] <- test


  if (transcriptDetails)
  {
    cat("\nAnnotating 3' UTRs")
    df$UTR3 <- ""
    UTR_3_GR <- threeUTRsByTranscript(gtf_TxDb)
    all_UTR_3_hits <- findOverlaps(gr , UTR_3_GR,type = annotationType)
    idx_to_annotate_3UTR <- queryHits(all_UTR_3_hits)
    df$UTR3[idx_to_annotate_3UTR] <- "YES"

    cat("\nAnnotating 5' UTRs")
    df$UTR5 <- ""
    UTR_5_GR <- fiveUTRsByTranscript(gtf_TxDb)
    all_UTR_5_hits <- findOverlaps(gr , UTR_5_GR,type = annotationType)
    identified_5UTRs <- UTR_5_GR[subjectHits(all_UTR_5_hits)]$exon_id
    idx_to_annotate_5UTR <- queryHits(all_UTR_5_hits)
    df$UTR5[idx_to_annotate_5UTR] <- "YES"

    cat("\nAnnotating introns")
    df$intron <- ""
    introns_GR <- intronsByTranscript(gtf_TxDb)
    all_intron_hits <- findOverlaps(gr , introns_GR, type = annotationType)
    identified_introns <- introns_GR[subjectHits(all_intron_hits)]
    idx_to_annotate_introns <- queryHits(all_intron_hits)
    df$intron[idx_to_annotate_introns] <- "YES"

    cat("\nAnnotating exons")
    my_exons <- gtf_gr[gtf_gr$type == "exon"]
    all_exon_hits <-  findOverlaps(gr , my_exons, type = annotationType)
    idx_to_annotate_exons <- queryHits(all_exon_hits)
    df$exon <- ""
    df$exon[idx_to_annotate_exons] <- "YES"

    cat("\nAnnotating CDS")
    my_CDS <- gtf_gr[gtf_gr$type == "CDS"]
    all_CDS_hits <-  findOverlaps(gr , my_CDS, type = annotationType)
    idx_to_annotate_CDS <- queryHits(all_CDS_hits)
    df$CDS <- ""
    df$CDS[idx_to_annotate_CDS] <- "YES"

  }

  return(df)
}