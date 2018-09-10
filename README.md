# ensembleCNV

## Method Description

EsembleCNV is a novel ensemble learning framework to detect and genotype copy number variations (CNVs) using single nucleotide polymorphism (SNP) array data. EnsembleCNV a) identifies and eliminates batch effects at raw data level; b) assembles individual CNV calls into CNV regions (CNVRs) from multiple existing callers with complementary strengths by a heuristic algorithm; c) re-genotypes each CNVR with local likelihood model adjusted by global information across multiple CNVRs; d) refines CNVR boundaries by local correlation structure in copy number intensities; e) provides direct CNV genotyping accompanied with confidence score, directly accessible for downstream quality control and association analysis. 

More details can be found in the manuscript:

Zhongyang Zhang, Haoxiang Cheng, Xiumei Hong, Antonio F. Di Narzo, Oscar Franzen, Shouneng Peng, Arno Ruusalepp, Jason C. Kovacic, Johan LM Bjorkegren, Xiaobin Wang, Ke Hao (2018) EnsembleCNV: An ensemble machine learning algorithm to identify and genotype copy number variation using SNP array data. bioRxiv 356667; doi: https://doi.org/10.1101/356667 

The detailed step-by-step instructions are listed as follows.

## Table of Contents

- [1 Initial call](#1-initial-call)
  - [Prepare chromosome-wise LRR and BAF matrices for CNV genotyping](#prepare-chromosome-wise-lrr-and-baf-matrices-for-cnv-genotyping)
  - [Prepare data for individual CNV callers](#prepare-data-for-individual-cnv-callers)
- [2 Batch effect](#2-batch-effect)
  - [PCA on raw LRR data](#pca-on-raw-lrr-data)
  - [PCA on summary statistics](#pca-on-summary-statistics)
- [3 Create CNVR](#3-create-cnvr)
- [4 CNV genotyping for each CNVR](#4-cnv-genotyping-for-each-cnvr)
  - [split cnvrs into batches](#split-cnvr-into-batches)
  - [regenotype](#regenotype)
  - [combine prediction results](#combine-prediction-results)
- [5 boundary refinement](#5-boundary-refinement)
- [6 performance assessment](#6-performance-assessment)
  - [compare duplicate pairs consistency rate](#compare-duplicate-pairs-consistency-rate)
- [test](#test)
  - [test ensembleCNV](#test-ensemblecnv)
  - [test regenotype](#test-regenotype)


## 1 Initial call

The pipeline begins with running inividual CNV callers, including [iPattern](https://www.ncbi.nlm.nih.gov/pubmed/?term=21552272), [PennCNV](http://penncnv.openbioinformatics.org/en/latest/), and [QuantiSNP](https://sites.google.com/site/quantisnp/), to make initial CNV calls. The raw data comes from the [final report](http://jp.support.illumina.com/content/dam/illumina-support/documents/documentation/software_documentation/genomestudio/genomestudio-2-0/genomestudio-genotyping-module-v2-user-guide-11319113-01.pdf) generated by Illumina [GenomeStudio](https://support.illumina.com/array/array_software/genomestudio.html). 

In the GenomeStudio, the exported final report text file is supposed to include at minimum the following 10 columns:
  - Sample ID
  - SNP Name 
  - Chr
  - Position
  - Allele 1 - Forward (or Allele 1 - Top) (used by iPattern)
  - Allele 2 - Forward (or Allele 2 - Top) (used by iPattern)
  - X (used by iPattern)
  - Y (used by iPattern)
  - Log R Ratio (used by PennCNV, QuantiSNP, and ensembleCNV)
  - B Allele Freq (used by PennCNV, QuantiSNP, and ensembleCNV)

The raw data needs to be converted into proper format required by ensembleCNV as well as inividual CNV callers.

### Prepare chromosome-wise LRR and BAF matrices for CNV genotyping

We provide [perl scripts](https://github.com/HaoKeLab/ensembleCNV/tree/master/01_initial_call/finalreport_to_matrix_LRR_and_BAF) to extract LRR and BAF information from final report, combine them across individuals and divide them by chromsomes.

(1) Create LRR and BAF (tab delimited) matrices from final report
```perl
perl finalreport_to_matrix_LRR_and_BAF.pl \
path_to_finalreport \
path_to_LRR_BAF_matrices
```
(2) Tansform tab-delimited text file to .rds format for quick loading in R
```sh
Rscript tranform_from_tab_to_rds.R path_input path_output chr_start chr_end
```
Here `path_input` is supposed to be `path_to_LRR_BAF_matrices` in the previous step.

When finishing running the scripts, there will be two folders `LRR` and `BAF` created under `path_to_LRR_BAF_matrices`. In `LRR` (`BAF`) folder, you will see LRR (BAF) matrices stored in `matrix_chr_*_LRR.rds` (`matrix_chr_*_BAF.rds`) for each chromosome respectively. In the matrix, each row corresponds to a sample while each column a SNP. The data will be later used for CNV genotyping for each CNVR.

### Prepare data for individual CNV callers

We provide [perl scripts](https://github.com/HaoKeLab/ensembleCNV/tree/master/01_initial_call/prepare_IPQ_input_file) to extract information from final report and convert the data into the formatted input files required by iPattern, PennCNV and QuantiSNP.

#### iPattern
```sh
perl finalreport_to_iPattern.pl \
-prefix path_to_save_ipattern_input_file/ \
-suffix .txt \
path_to_finalreport
```

#### PennCNV
```sh
perl finalreport_to_PennCNV.pl \
-prefix path_to_save_penncnv_input_file/ \
-suffix .txt \
path_to_finalreport
```

#### QuantiSNP
```sh
perl finalreport_to_QuantiSNP.pl \
-prefix path_to_save_quantisnp_input_file/ \
-suffix .txt \
path_to_finalreport
```

To run each individual CNV caller, we provide auxiliary scripts for [iPattern](https://github.com/HaoKeLab/ensembleCNV/tree/master/01_initial_call/run_iPattern), [PennCNV](https://github.com/HaoKeLab/ensembleCNV/tree/master/01_initial_call/run_PennCNV) and [QuantiSNP](https://github.com/HaoKeLab/ensembleCNV/tree/master/01_initial_call/run_QuantiSNP). We encourage users to consult with the original documents of these methods for more details. 


## 2 Batch effect

Two orthogonal signals can be used to identify batch effects in CNV calling: (i) Batch effects may be reflected in the first two or three PCs when principle component analysis (PCA) is applied on the raw LRR matrix. We randomly select 100,000 probes and apply PCA to the down-sampled matrix to save computational time. (ii) Along with CNV calls, the three detection methods generate sample-wise summary statistics, such as standard deviations (SD) of LRR, SD of BAF, wave factor in LRR, BAF drift, and the number of CNVs detected, reflecting the quality of CNV calls at the sample level.  Since these quantities are highly correlated among themselves and between methods, we also use PCA to summarize their information.  By examining the first two or three PCs visualized in scatter plots, we can identify sample outliers or batches that deviate from the majority of the normally behaved samples. 

Note: While isolated outliers should be excluded from downstream analysis, if batch effects are identified, the users need to re-normalize the samples within each outstanding batch with Genome Studio respectively. The initial CNV calling step with individual CNV callers need to be performed again on the updated data. The re-called CNVs will be combined with the remaining call set of good quality. Also, the chromosome-wise LRR and BAF matrices prepared for CNV genotyping need to be updated as done in the [initial step](#prepare-chromosome-wise-lrr-and-baf-matrices-for-cnv-genotyping).

### PCA on raw LRR data

This analysis is implemented in the following 3 steps.

(1) Randomly select 100,000 SNPs based on information from SNP_Map.txt generated from Genome Studio, which is supposed to include at least three columns: Name, Chromosome, Position. The information in SNP_Map.txt can be also retrieved from final report.
```sh
Rscript step.1.down.sampling.R \
/path/to/SNP_Map.txt \ ## SNP_Map.txt generated from Genome Studio
path_to_output
```

(2) Extract LRR values at the list of randomly selected SNPs across individuals from final report file generated by Genome Studio.
```sh
perl step.2.LRR.matrix.pl \
/path/to/snps.down.sample.txt \   ## the list of SNPs generated in step (1)
/path/to/final_report.txt \       ## generated by Genome Studio
/path/to/output_LRR_matrix_file
```

(3) PCA on LRR matrix.
```sh
Rscript step.3.LRR.PCA.R \
/path/to/wk_dir/ \       ## working directory where the LRR matrix is located and results will be saved for PCA
filename_of_LRR_matrix   ## the LRR matrix generated in step (2)
``` 
When the analysis is finished, in the working directory, the first three PCs of all samples will be saved in tab-delimited text file, and scatter plots of the first three PCs will also be generated. 

### PCA on summary statistics

Besides CNV calls, iPattern, PennCNV and QuantiSNP also generate 10 sample-level statistics: (a) SD of normalzied total intensity, and b) number of CNVs detected per sample from iPattern; (c) SD of LRR, (d) SD of BAF, (e) wave factor in LRR, (f) BAF drift, and (g) number of CNVs detected per sample from PennCNV; (h) SD of LRR, (i) SD of BAF, and (j) number of CNVs detected per sample from QuantiSNP. PCA can be performed in the follwoing 2 steps.

(1) Generate iPattern, PennCNV and QuantiSNP sample-level summary statistics.
```sh
Rscript step.1.prepare.stats.R \
/path/to/iPattern/results/ \
/path/to/PennCNV/results/ \
/path/to/QuantiSNP/results/ \
/path/to/output/  ## saving summary statistics from iPattern, PennCNV and QuantiSNP results
```

(2) PCA on sample-level summary statistics.
```sh
Rscript step.2.stats.PCA.R \
/path/to/wk_dir/ ## this is the path to IPQ.stats.txt generated in step (1)
```
When the analysis is finished, in the working directory, the PCs of all samples will be saved in tab-delimited text file, and scatter plots of the first three PCs will also be generated. 


## 3 Create CNVR

We defined copy number variable region (CNVR) as the region in which CNVs called from different individuals by different callers substantially overlap with each other. We modeled the CNVR construction problem as identification of cliques (a sub-network in which every pair of nodes is connected) in a network context, where (i) CNVs detected for each individual from a method are considered as nodes; (ii) two nodes are connected when the reciprocal overlap between their corresponding CNV segments is greater than a pre-specified threshold (e.g. 30%); (iii) a clique corresponds to a CNVR in the sense that, for each CNV (node) belonging to the CNVR (clique), its average overlap with all the other CNVs of this CNVR is above a pre-specified threshold (e.g. 30%). The computational complexity for clique identification can be dramatically reduced in this special case, since the CNVs can be sorted by their genomic locations and the whole network can be partitioned by chromosome arms – CNVs from different arms never belong to the same CNVR. More details can be found in the [manuscript](https://doi.org/10.1101/356667).

The algorithm is implemented in the following two steps.

(1) Extract CNV information from individual calls made by iPattern, PennCNV and QuantiSNP
```sh
Rscript step.1.CNV.data.R \
/path/to/working_directory \   ## where output files are saved
/path/to/iPattern_CNV_file \
/path/to/PennCNV_CNV_file \
/path/to/QuantiSNP_CNV_file \
/path/to/Sample_Map.txt   ## generated along with final report from Genome Studio
```
After finishing this step, three tab-delimited tables for each respective method, `cnv.ipattern.txt`, `cnv.penncnv.txt`, and `cnv.quantisnp.txt`, will be generated with such fields as `Sample_ID`, `chr`, `posStart`, `posEnd`, `CNV_type`, etc. These files will be used as input in the following step (2).

(2) Merge CNV calls from individual methods into CNVRs
```sh
Rscript step.2.create.CNVR.R \
--icnv /path/to/iPattern_CNV_call \   ## generated in step (1)
--pcnv /path/to/PennCNV_CNV_call \
--qcnv /path/to/QuantiSNP_CNV_call \
--snp /path/to/SNP_position_file \   ## SNP.pfb for PennCNV analysis can serve for SNP position
--centromere /path/to/chromosome_centromere_file   ## the information can be found in UCSC genome browser
```
Two tab-delimited tables will be generated in this step: i) `cnvr_clean.txt` with the information for each constructed CNVR; ii) `cnv_clean.txt` with the information for each CNV calls from individual methods, including which CNVR each CNV belongs to.

We provide an [example](https://github.com/HaoKeLab/ensembleCNV/tree/master/example/example_create_CNVR) of input and output files corresponding to one sample CNVR.

## 4 CNV genotyping for each CNVR

The initial CNV calls within a CNVR may be mixed with false positives and false negatives from the initial call set. Moreover, the baseline LRR value corresponding to normal CN status may substantially deviate from 0, violating the essential model assumptions for individual-wise CNV callers (e.g., PennCNV and QuantiSNP). To address these issues, we re-genotyped CN status per individual at each CNVR by a locally fitted likelihood model, with information from other CNVRs borrowed for the initialization of model parameters. Both the LRR and BAF signals from SNP probes and the LRR signal from CNV probes within a particular CNVR were used for model fitting. More details can be found in the [manuscript](https://doi.org/10.1101/356667).

In current implementation, CNVRs within different chromosomes are processed in parallel, and CNVRs within the same chromosomes are further grouped into batches for additional level of parallelization. Relevant R scripts can be found [here](https://github.com/HaoKeLab/ensembleCNV/tree/master/04_CNV_genotype). The main script `CNV.genotype.one.chr.one.batch.R` does CNV genotyping on one batch of CNVRs within one chromosome at a time. It loads the R functions in the subdirectory [scripts](https://github.com/HaoKeLab/ensembleCNV/tree/master/04_CNV_genotype/scripts) when being run in an R seesion.

Running CNV genotyping in parallel is implemented in the following four steps.

(1) Split CNVRs into different batches in each chromosome.
```sh
Rscript step.1.split.cnvrs.into.batches.R \
-i /path/to/cnvr_clean.txt \  ## generated in "create CNVR" step
-o /path/to/data/cnvr_batch.txt \
-n 200
```
The parameter `-n 200` indicates the maximum number of CNVRs in each batch. The script goes over the table of CNVRs in `cnvr_clean.txt` generated in the previous "create CNVR" step, appends to the table an additional column indicating the batches each CNVR belongs to, and writes the updated table to tab-delimited file `cnvr_batch.txt`.

(2) Submit parallelized jobs for CNV genotyping, each corresponding to one batch in one chromosome.

Before running the script below, the following files prepared in previous steps need to be copied in the `/path/to/data/` directory, where `cnvr_batch.txt` is located, and renamed exactly as follows:

  - `SNP.pfb` (prepared when running PennCNV; containing the column of PFB (Population Frequency of B allele) used in this step)
  - `cnv_clean.txt` (generated in "create CNVR" step)
  - `sample_QC.txt` (renamed from `CNV.PennCNV_qc_new.txt`, which is generated when finishing PennCNV analysis; the columns "LRR_mean" and "LRR_sd" are used in this step)
  - `duplicate_pairs.txt` (optional) (tab-delimited table of two columns with header names: "sample1.name" and "sample2.name"; each row is a duplicated pair with one sample ID in the first column and the other in the second column)

Rscript step.2.submit.jobs.R \
--type 0 \ ## "0" indicates initial submission
--datapath /path/to/data/ \  ## the above input files are all placed in this folder
--resultpath /path/to/results/ \  ## directory to save results
--matrixpath /path/to/chromosome wise LRR and BAF matrices/ \  ## generated in the intial step
--sourcefile /path/to/scripts/ \  ## where relavent R functions are placed (see above)
--duplicates \  ## (optional) indicates whether the information duplicate pairs is used in diagnosis plots
--plot \  ## (optional) indicates whether diagnosis plots to be generated
--script /path/to/main script/ \  ## where CNV.genotype.one.chr.one.batch.R is placed
--joblog /path/to/log directory/ ## where jobs log files to be placed




```sh
sample code:
./step.2.regenotype.each.chr.each.batch.R \
-c 1 -b 1 -t 0 -p path_data -o path_result -m path_matrix -s path_sourcefile

./step.2.regenotype.each.chr.each.batch.R --help for detail

```

combine all sample-based regenotype results.
and, generate mat_CN.rds (matrix of regenotype copy number),
matrix_GQ.rds (matrix of regenotype gq score), 
CNVR_ID.rds (rownames of matrix),
Sample_ID.rds( columns of matrix).

explation:
path_cnvr (with cnvrs_annotated_batch.rds)
path_pred (with chr-batch-based regenotype results)
path_res (save results: matrix_CN.rds matrix_GQ.rds)
```sh
./step.5.prediction.results.R n.samples path_cnvr path_pred pred_res
```

## 5 Boundary refinement

There are 5 steps in boundary refinement, as following:

All scripts are in folder 05_boundary_refinement.

The main part is script named as step.2.boundary_refinement.R:
```sh
./step.2.boundary_refinement.R --help for detail
```

## 6 Performance assessment

summary compare results between all CNV calling methods with ensembleCNV method.
copy all following files to path_input:
dup_samples.rds with columns: sample1.name, sample1.name
matrix_iPattern.rds; matrix_PennCNV.rds; matrix_QuantiSNP.rds; 
matrix_IPQ_intersect.rds; matrix_IPQ_union.rds; matrix_ensembleCNV.rds

### compare duplicate pairs consistency rate

```sh
./compare.dups.consistency.R path_input cohort_name path_output
```
## test
here, we supply a samll test example for user to test.

copy all the scripts and data folder in test working folder.

### test ensembleCNV

```sh
mkdir res
./step.2.ensembleCNV.R \
-i ./test_data_ensembleCNV/cnvr1.ipattern.rds \
-p ./test_data_ensembleCNV/cnvr1.penncnv.rds \
-q ./test_data_ensembleCNV/cnvr1.quantisnp.rds \
-s ./test_data_ensembleCNV/SNP.cnvr1.pfb \
-c ./test_data_ensembleCNV/chr_centromere_hg19.rds \
-o ./res
```

### test regenotype

```sh
mkdir script; cp 04_genotype/script/* .
```
and, run test_regenotype.R line by line to generate regenotype copyt number results.


