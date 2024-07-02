# smallBamQc

Generate BAM file metrics for OICR's QC Gates as fast as possible. See DESIGN.md for details.

## Overview

## Dependencies

* [samtools 1.16.1](http://www.htslib.org/)
* [picard 2.21.2](https://broadinstitute.github.io/picard/)
* [bedtools 2.27](https://bedtools.readthedocs.io)


## Usage

### Cromwell
```
java -jar cromwell.jar run smallBamQc.wdl --inputs inputs.json
```

### Inputs

#### Required workflow parameters:
Parameter|Value|Description
---|---|---
`bam`|File|The BAM file to analyze.
`opticalDuplicatePixelDistance`|Int|For MarkDuplicates. The maximum offset between two duplicate clusters in order to consider them optical duplicates. 100 is appropriate for unpatterned versions of the Illumina platform. For the patterned flowcell models, 2500 is more appropriate.
`outputFileNamePrefix`|String|String to add to the output file names.


#### Optional workflow parameters:
Parameter|Value|Default|Description
---|---|---|---
`bedtoolsReadsToUse`|Int?|None|If defined, use that many reads from the beginning of the BAM file for bedtools analysis. If not defined, use all BAM reads.
`features`|String?|None|If defined, bedtools calculates coverage for those features only. If not defined, calculate coverage for all reads (whole genome).
`featuresToUse`|Int?|None|If defined, use that many features from the beginning of the features file. If not defined, use all features.
`picardMarkDuplicatesReadsToUse`|Int?|None|If defined, MarkDuplicates uses that many reads from the beginning of the BAM file. If not defined, use all BAM reads. Note that a new BAM file is created if defined, so using a large number will temporarily generate a second large BAM file.
`samtoolsStatsReadsToUse`|Int?|None|If defined, use that many read from the beginning of the BAM file for samtools stats. If not defined, use all BAM reads.


#### Optional task parameters:
Parameter|Value|Default|Description
---|---|---|---
`samtoolsStatsSmall.timeout`|Int|1|The hours until the task is killed.
`samtoolsStatsSmall.memory`|Int|2|The GB of memory provided to the task.
`samtoolsStatsSmall.threads`|Int|4|The number of threads the task has access to.
`samtoolsStatsSmall.modules`|String|"samtools/1.16.1"|The modules that will be loaded.
`samtoolsStatsFull.timeout`|Int|6|The hours until the task is killed.
`samtoolsStatsFull.memory`|Int|2|The GB of memory provided to the task.
`samtoolsStatsFull.threads`|Int|4|The number of threads the task has access to.
`samtoolsStatsFull.modules`|String|"samtools/1.16.1"|The modules that will be loaded.
`samtoolsHead.timeout`|Int|6|The hours until the task is killed.
`samtoolsHead.memory`|Int|2|The GB of memory provided to the task.
`samtoolsHead.threads`|Int|4|The number of threads the task has access to.
`samtoolsHead.modules`|String|"samtools/1.16.1"|The modules that will be loaded.
`markDuplicates.picardMaxMemMb`|Int|6000|Memory requirement in MB for running Picard JAR.
`markDuplicates.modules`|String|"picard/2.21.2"|required environment modules.
`markDuplicates.jobMemory`|Int|16|Memory allocated for this job.
`markDuplicates.threads`|Int|4|Requested CPU threads.
`markDuplicates.timeout`|Int|12|hours before task timeout.
`featuresHead.modules`|String|""|The modules that will be loaded.
`featuresHead.memory`|Float|0.1|The GB of memory provided to the task.
`featuresHead.threads`|Int|1|The number of threads the task has access to.
`featuresHead.timeout`|Int|1|The hours until the task is killed.
`bedtoolsCoverageFull.modules`|String|"bedtools/2.27 samtools/1.16.1"|The modules that will be loaded.
`bedtoolsCoverageFull.memory`|Int|4|The GB of memory provided to the task.
`bedtoolsCoverageFull.threads`|Int|2|The number of threads the task has access to.
`bedtoolsCoverageFull.timeout`|Int|12|The hours until the task is killed.
`bedtoolsCoverageSmall.modules`|String|"bedtools/2.27 samtools/1.16.1"|The modules that will be loaded.
`bedtoolsCoverageSmall.memory`|Int|4|The GB of memory provided to the task.
`bedtoolsCoverageSmall.threads`|Int|2|The number of threads the task has access to.
`bedtoolsCoverageSmall.timeout`|Int|1|The hours until the task is killed.
`storeDownsampledCounts.modules`|String|""|The modules that will be loaded.
`storeDownsampledCounts.memory`|Float|0.1|The GB of memory provided to the task.
`storeDownsampledCounts.threads`|Int|1|The number of threads the task has access to.
`storeDownsampledCounts.timeout`|Int|1|The hours until the task is killed.


### Outputs

Output | Type | Description | Labels
---|---|---|---
`samtools`|File|Samtools stats output|vidarr_label: samtools
`picard`|File|Picard MarkDuplicates output|vidarr_label: picard
`bedtoolsCoverage`|File|Bedtools coverage histogram output|vidarr_label: bedtoolsCoverage
`downsampledCounts`|File|JSON file recording what downsampling was done|vidarr_label: downsampledCounts


## Commands
 See WDL and DESIGN.md ## Support

For support, please file an issue on the [Github project](https://github.com/oicr-gsi) or send an email to gsi@oicr.on.ca .

_Generated with generate-markdown-readme (https://github.com/oicr-gsi/gsi-wdl-tools/)_
