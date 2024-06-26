version 1.0

workflow smallBamQc {
    input {
        File bam
        Int opticalDuplicatePixelDistance
        String outputFileNamePrefix
        Int? bedtoolsReadsToUse
        String? features  # This is a file path, but using the `File` type doesn't play well with Shesmu/Vidarr type system
        Int? featuresToUse
        Int? picardMarkDuplicatesReadsToUse
        Int? samtoolsStatsReadsToUse
    }


    parameter_meta {
        bam: "The BAM file to analyze."
        opticalDuplicatePixelDistance: "For MarkDuplicates. The maximum offset between two duplicate clusters in order to consider them optical duplicates. 100 is appropriate for unpatterned versions of the Illumina platform. For the patterned flowcell models, 2500 is more appropriate."
        outputFileNamePrefix: "String to add to the output file names."
        bedtoolsReadsToUse: "If defined, use that many reads from the beginning of the BAM file for bedtools analysis. If not defined, use all BAM reads."
        features: "If defined, bedtools calculates coverage for those features only. If not defined, calculate coverage for all reads (whole genome)."
        featuresToUse: "If defined, use that many features from the beginning of the features file. If not defined, use all features."
        picardMarkDuplicatesReadsToUse: "If defined, MarkDuplicates uses that many reads from the beginning of the BAM file. If not defined, use all BAM reads. Note that a new BAM file is created if defined, so using a large number will temporarily generate a second large BAM file."
        samtoolsStatsReadsToUse: "If defined, use that many read from the beginning of the BAM file for samtools stats. If not defined, use all BAM reads."
    }

    if (defined(samtoolsStatsReadsToUse)) {
        Int toUseStats = select_first([samtoolsStatsReadsToUse])
        call samtoolsStatsSmall {
            input:
                bam = bam,
                outputFileNamePrefix = outputFileNamePrefix,
                readsToUse = toUseStats
        }
    }

    if (!defined(samtoolsStatsReadsToUse)) {
        call samtoolsStatsFull {
            input:
                bam = bam,
                outputFileNamePrefix = outputFileNamePrefix
        }
    }

    if (defined(picardMarkDuplicatesReadsToUse)) {
        Int toUsePicard = select_first([picardMarkDuplicatesReadsToUse])
        call samtoolsHead {
            input:
                bam = bam,
                readsToUse = toUsePicard
        }
    }

    File inputForPicard = select_first([samtoolsHead.out, bam])
    call markDuplicates {
        input:
            bamFile = inputForPicard,
            outputFileNamePrefix = outputFileNamePrefix,
            opticalDuplicatePixelDistance = opticalDuplicatePixelDistance
    }

    if (defined(features)) {
        call featuresHead {
            input:
                features = select_first([features]),
                featuresToUse = featuresToUse
        }
    }

    if (!defined(bedtoolsReadsToUse)) {
        call bedtoolsCoverageFull {
            input:
                bam = bam,
                features = featuresHead.out,
                outputFileNamePrefix = outputFileNamePrefix
        }
    }

    if (defined(bedtoolsReadsToUse)) {
        Int toUseBedtools = select_first([bedtoolsReadsToUse])
        call bedtoolsCoverageSmall {
            input:
                bam = bam,
                features = featuresHead.out,
                readsToUse = toUseBedtools,
                outputFileNamePrefix = outputFileNamePrefix
        }
    }

    call storeDownsampledCounts {
        input:
            outputFileNamePrefix = outputFileNamePrefix,
            bedtoolsReadsToUse = bedtoolsReadsToUse,
            featuresCount = featuresHead.count,
            featuresInputCount = featuresHead.total_count,
            picardMarkDuplicatesReadsToUse = picardMarkDuplicatesReadsToUse,
            samtoolsStatsReadsToUse = samtoolsStatsReadsToUse
    }

    output {
        File samtools = select_first([samtoolsStatsFull.out, samtoolsStatsSmall.out])
        File picard = markDuplicates.result
        File bedtoolsCoverage = select_first([bedtoolsCoverageFull.out, bedtoolsCoverageSmall.out])
        File downsampledCounts = storeDownsampledCounts.out
    }

    meta {
        author: "Savo Lazic"
        email: "slazic@oicr.on.ca"
        description: "Generate BAM file metrics for OICR's QC Gates as fast as possible. See DESIGN.md for details."
        dependencies: [
            {
                name: "samtools/1.16.1",
                url: "http://www.htslib.org/"
            },
            {
                name: "picard/2.21.2",
                url: "https://broadinstitute.github.io/picard/"
            },
            {
                name: "bedtools/2.27",
                url : "https://bedtools.readthedocs.io"
            }
        ]
    output_meta: {
    samtools: {
        description: "Samtools stats output",
        vidarr_label: "samtools"
    },
    picard: {
        description: "Picard MarkDuplicates output",
        vidarr_label: "picard"
    },
    bedtoolsCoverage: {
        description: "Bedtools coverage histogram output",
        vidarr_label: "bedtoolsCoverage"
    },
    downsampledCounts: {
        description: "JSON file recording what downsampling was done",
        vidarr_label: "downsampledCounts"
    }
}
    }
}

task samtoolsStatsSmall {
    input {
        File bam
        String outputFileNamePrefix
        Int readsToUse
        Int timeout = 1
        Int memory = 2
        Int threads = 4
        String modules = "samtools/1.16.1"
    }

    command <<<
        set -euo pipefail
        # Non-primary reads (same read aligned multipe times) and supplementary reads (same read split up and each split aligned indpendantly) are excluded
        # from samtools stats by defaut. This ensures the total read count of samtools stats matches the total reads produced by the machine
        samtools head -n ~{readsToUse} --threads ~{threads} ~{bam} | samtools stats - > ~{outputFileNamePrefix}.stats.txt
    >>>

    output {
        File out = "~{outputFileNamePrefix}.stats.txt"
    }

    parameter_meta {
        bam: "The BAM file to analyze."
        outputFileNamePrefix: "String to add to the output file names."
        readsToUse: "The number of reads to feed into the analysis."
        timeout: "The hours until the task is killed."
        memory: "The GB of memory provided to the task."
        threads: "The number of threads the task has access to."
        modules: "The modules that will be loaded."
    }

    meta {
        output_meta: {
            out: "The samtools stats output for the downsamples BAM."
        }
    }

    runtime {
        modules: "~{modules}"
        memory:  "~{memory} GB"
        cpu:     "~{threads}"
        timeout: "~{timeout}"
    }
}

task samtoolsStatsFull {
    input {
        File bam
        String outputFileNamePrefix
        Int timeout = 6
        Int memory = 2
        Int threads = 4
        String modules = "samtools/1.16.1"
    }

    command <<<
        set -euo pipefail
        # Non-primary reads (same read aligned multipe times) and supplementary reads (same read split up and each split aligned indpendantly) are excluded
        # from samtools stats by default. This ensures the total read count of samtools stats matches the total reads produced by the machine
        samtools stats --threads ~{threads} ~{bam} > ~{outputFileNamePrefix}.stats.txt
    >>>

    output {
        File out = "~{outputFileNamePrefix}.stats.txt"
    }

    parameter_meta {
        bam: "The BAM file to analyze."
        outputFileNamePrefix: "String to add to the output file names."
        timeout: "The hours until the task is killed."
        memory: "The GB of memory provided to the task."
        threads: "The number of threads the task has access to."
        modules: "The modules that will be loaded."
    }

    meta {
        output_meta: {
            out: "The samtools stats output for the full BAM."
        }
    }

    runtime {
        modules: "~{modules}"
        memory:  "~{memory} GB"
        cpu:     "~{threads}"
        timeout: "~{timeout}"
    }
}

task samtoolsHead {
    input {
        File bam
        Int readsToUse
        Int timeout = 6
        Int memory = 2
        Int threads = 4
        String modules = "samtools/1.16.1"
    }

    command <<<
        set -euo pipefail
        samtools head -n ~{readsToUse} --threads ~{threads} ~{bam} > out.sam
    >>>

    output {
        File out = "out.sam"
    }

    parameter_meta {
        bam: "The BAM file to analyze."
        readsToUse: "The number of reads to generate the new file with."
        timeout: "The hours until the task is killed."
        memory: "The GB of memory provided to the task."
        threads: "The number of threads the task has access to."
        modules: "The modules that will be loaded."
    }

    meta {
        output_meta: {
            out: "The downsampled SAM file."
        }
    }

    runtime {
        modules: "~{modules}"
        memory:  "~{memory} GB"
        cpu:     "~{threads}"
        timeout: "~{timeout}"
    }
}

task markDuplicates {
    input {
        File bamFile
        String outputFileNamePrefix
        Int opticalDuplicatePixelDistance
        Int picardMaxMemMb=6000
        String modules = "picard/2.21.2"
        Int jobMemory = 16
        Int threads = 4
        Int timeout = 12
    }

    parameter_meta {
        bamFile: "Input BAM file, after filtering and downsampling (if any)."
        outputFileNamePrefix: "Prefix for output file."
        opticalDuplicatePixelDistance: "Maximum offset between optical duplicate clusters."
        picardMaxMemMb: "Memory requirement in MB for running Picard JAR."
        modules: "required environment modules."
        jobMemory: "Memory allocated for this job."
        threads: "Requested CPU threads."
        timeout: "hours before task timeout."
    }

    String outFileText = "~{outputFileNamePrefix}.markDuplicates.txt"

    command <<<
        set -euo pipefail
        java -Xmx~{picardMaxMemMb}M \
        -jar ${PICARD_ROOT}/picard.jar \
        MarkDuplicates \
        INPUT=~{bamFile} \
        OUTPUT=/dev/null \
        VALIDATION_STRINGENCY=SILENT \
        TMP_DIR=${PWD} \
        METRICS_FILE=~{outFileText} \
        OPTICAL_DUPLICATE_PIXEL_DISTANCE=~{opticalDuplicatePixelDistance}
    >>>

    runtime {
        modules: "~{modules}"
        memory:  "~{jobMemory} GB"
        cpu:     "~{threads}"
        timeout: "~{timeout}"
    }

    output {
        File result = "~{outFileText}"
    }

    meta {
        output_meta: {
            result: "Text file with Picard markDuplicates metrics."
        }
    }
}

task featuresHead {
    input {
        String features
        Int? featuresToUse
        String modules = ""
        Float memory = 0.1
        Int threads = 1
        Int timeout = 1
    }

    String cmd = if defined(featuresToUse) then "head -n ~{featuresToUse} " else "cat "

    command <<<
        set -euo pipefail

        ~{cmd} ~{features} > out.features
        wc -l < ~{features} > total.features.count
        wc -l < out.features
    >>>

    output {
        File out = "out.features"
        Int total_count = read_int("total.features.count")
        Int count = read_int(stdout())
    }

    parameter_meta {
        features: "The features file"
        featuresToUse: "How many features to use. All if undefined."
        timeout: "The hours until the task is killed."
        memory: "The GB of memory provided to the task."
        threads: "The number of threads the task has access to."
        modules: "The modules that will be loaded."
    }

    meta {
        output_meta: {
            out: "The full or downsampled features file.",
            total_count: "The number of features in the input file.",
            count: "How many features in the out file."
        }
    }

    runtime {
        modules: "~{modules}"
        memory:  "~{memory} GB"
        cpu:     "~{threads}"
        timeout: "~{timeout}"
    }
}

task bedtoolsCoverageFull {
    input {
        File bam
        String? features
        String outputFileNamePrefix
        String modules = "bedtools/2.27 samtools/1.16.1"
        Int memory = 4
        Int threads = 2
        Int timeout = 12
    }

    String bedcmd = if defined(features) then "bedtools coverage -a ~{features} -b stdin -hist -sorted -g chrom.size" else "bedtools genomecov -ibam stdin"
    # bedtools collects coverage across all regions, but names that row differently between `coverage` and `genomecov`
    String grepstr = if defined(features) then '"^all"' else '"^genome"'

    command <<<
        set -euo pipefail
        # Bedtools needs chromosome sizes, but can't extract them from the BAM file
        samtools view -H ~{bam} | \
            grep "^@SQ" | \
            awk 'BEGIN { OFS = "\t" } ; {print substr($2, 4), substr($3, 4)}' > chrom.size

        # bedtools finishes before samtools stops streaming. This causes samtools to close with return code 141
        # As pipefail is enabled, the return code for the task if 141, even though everything went fine
        # The `if [[ $? -eq 141 ]]` shenanigans ensure samtools exits with 0 in that case
        # The other solution is for samtools to only return the reads bedtools expects (-L flag), but this duplicates effort
        # https://stackoverflow.com/questions/22464786/ignoring-bash-pipefail-for-error-code-141
        (samtools view -uF 256 ~{bam} || if [[ $? -eq 141 ]]; then true; else exit $?; fi) | \
            ~{bedcmd} | \
            grep ~{grepstr} > ~{outputFileNamePrefix}.coverage.hist
    >>>

    output {
        File out = "~{outputFileNamePrefix}.coverage.hist"
    }

    parameter_meta {
        bam: "The BAM file to analyze."
        features: "If defined, bedtools calculates coverage for those features only. If not defined, calculate coverage for all reads (whole genome)."
        outputFileNamePrefix: "String to add to the output file names."
        timeout: "The hours until the task is killed."
        memory: "The GB of memory provided to the task."
        threads: "The number of threads the task has access to."
        modules: "The modules that will be loaded."
    }

    meta {
        output_meta: {
            out: "Tabular histogram of coverage."
        }
    }

    runtime {
        modules: "~{modules}"
        memory:  "~{memory} GB"
        cpu:     "~{threads}"
        timeout: "~{timeout}"
    }
}

task bedtoolsCoverageSmall {
    input {
        File bam
        String? features
        Int readsToUse
        String outputFileNamePrefix
        String modules = "bedtools/2.27 samtools/1.16.1"
        Int memory = 4
        Int threads = 2
        Int timeout = 1
    }

    String bedcmd = if defined(features) then "bedtools coverage -a ~{features} -b stdin -hist -sorted -g chrom.size" else "bedtools genomecov -ibam stdin"
    # bedtools collects coverage across all regions, but names that row differently between `coverage` and `genomecov`
    String grepstr = if defined(features) then '"^all"' else '"^genome"'

    command <<<
        set -euo pipefail
        # Bedtools needs chromosome sizes, but can't extract them from the BAM file
        samtools view -H ~{bam} | \
            grep "^@SQ" | \
            awk 'BEGIN { OFS = "\t" } ; {print substr($2, 4), substr($3, 4)}' > chrom.size

        # see bedtoolsCoverageFull task for explanation of `if [[ $? -eq 141 ]]` shenanigans
        (samtools view -uF 256 --threads ~{threads} ~{bam} || if [[ $? -eq 141 ]]; then true; else exit $?; fi) | \
            (samtools head -n ~{readsToUse} --threads ~{threads} - || if [[ $? -eq 141 ]]; then true; else exit $?; fi) | \
            (samtools view -u --threads ~{threads} - || if [[ $? -eq 141 ]]; then true; else exit $?; fi) |  # bedtools does not work with sam
            ~{bedcmd} | \
            grep ~{grepstr} > ~{outputFileNamePrefix}.coverage.hist
    >>>

    output {
        File out = "~{outputFileNamePrefix}.coverage.hist"
    }

    parameter_meta {
        bam: "The BAM file to analyze."
        features: "If defined, bedtools calculates coverage for those features only. If not defined, calculate coverage for all reads (whole genome)."
        readsToUse: "The number of reads from the head of the BAM file to use in the analysis."
        outputFileNamePrefix: "String to add to the output file names."
        timeout: "The hours until the task is killed."
        memory: "The GB of memory provided to the task."
        threads: "The number of threads the task has access to."
        modules: "The modules that will be loaded."
    }

    meta {
        output_meta: {
            out: "Tabular histogram of coverage from the downsampled data."
        }
    }

    runtime {
        modules: "~{modules}"
        memory:  "~{memory} GB"
        cpu:     "~{threads}"
        timeout: "~{timeout}"
    }
}

task storeDownsampledCounts {
    input {
        String outputFileNamePrefix
        Int? bedtoolsReadsToUse
        Int? featuresCount
        Int? featuresInputCount
        Int? picardMarkDuplicatesReadsToUse
        Int? samtoolsStatsReadsToUse
        String modules = ""
        Float memory = 0.1
        Int threads = 1
        Int timeout = 1
    }

    String bedtools_reads = if defined(bedtoolsReadsToUse) then "~{bedtoolsReadsToUse}" else "null"
    String bedtools_features = if defined(featuresCount) then "~{featuresCount}" else "null"
    String bedtools_features_input = if defined(featuresInputCount) then "~{featuresInputCount}" else "null"
    String picard_reads = if defined(picardMarkDuplicatesReadsToUse) then "~{picardMarkDuplicatesReadsToUse}" else "null"
    String samtools_reads = if defined(samtoolsStatsReadsToUse) then "~{samtoolsStatsReadsToUse}" else "null"

    command  <<<
    set -euo pipefail
    echo '{"bedtools_reads": ~{bedtools_reads}, "bedtools_features": ~{bedtools_features}, "bedtools_features_input": ~{bedtools_features_input}, "picard_reads": ~{picard_reads}, "samtools_reads": ~{samtools_reads}}' > "~{outputFileNamePrefix}.downsample_count.json"
    >>>

    output {
        File out = "~{outputFileNamePrefix}.downsample_count.json"
    }

    parameter_meta {
        outputFileNamePrefix: "String to add to the output file names."
        bedtoolsReadsToUse: "How many reads were used for bedtools analysis."
        featuresCount: "The number of features used for bedtools analysis."
        featuresInputCount: "The number of features before downsampling."
        timeout: "The hours until the task is killed."
        memory: "The GB of memory provided to the task."
        threads: "The number of threads the task has access to."
        modules: "The modules that will be loaded."
    }

    meta {
        output_meta: {
            out: "Tabular histogram of coverage from the downsampled data."
        }
    }

    runtime {
        modules: "~{modules}"
        memory:  "~{memory} GB"
        cpu:     "~{threads}"
        timeout: "~{timeout}"
    }
}