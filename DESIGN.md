The reasoning for creating this workflow is found in the [project charter](https://docs.google.com/document/d/1wNfZL1yIn2HO5O6AVxXCGK-won5Nx_e5V98KUI4dUNk/edit#heading=h.cyxk68tr97gk): "To remove the bamqc workflow from emSeqQc and replace it with something simpler and faster."

To get simplicity and efficiency, only the work necessary to generate QC Gate metrics is done in parallel:

- samtools stats: mean/median insert size, total reads
- picard MarkDuplicates: duplication percentage
- bedtools: coverage histogram

The workflow supports features (probes) for coverage calculations. If supplied, only those regions will be used to calculate coverage. If not, coverage will be calculated for all sites in the genome.

samtools and picard output is not changed. For bedtools output, only the global coverage histogram is kept. The per-chromosome or per-feature histograms are discarded. That level of detail is not needed for QC Gate coverage metric and would result in large files (100MB - 1GB).

Downsampling of input data is the best way to increase efficiency (doing less is faster). Metrics such as duplication rate and mean insert size approach their true value with only millions of reads. Bamqc uses random downsampling to an exact count. As the whole BAM file has to be read, this method of downsampling is slow. It takes hours to downsample a large BAM file. To increase downsampling efficiency, smallBamQc takes only the first N reads for downsampling. Each task (samtools, picard, bedtools) can independently set how many reads to use. Downsampling is optional and won't be used if the downsampling parameter is not supplied. 

For samtools and bedtools, the downsampled BAM file is streamed. Picard MarkDuplicates requires a file on disk, as it is a dual pass algorithm. If downsampling is done for MarkDuplicates, selecting a large number of reads to downsample to will result in a new large BAM file on disk.

Read downsampling does not work with bedtools coverage calculations if features (probes) are supplied. For example, if the first probe is on chr13, there will be a variable number of off target reads on chr1 through chr12. Selecting the first N reads to downsample will not work. Rather than downsampling BAM input reads, it is possible to downsample features, by selecting only the first N features. It is possible to downsample for both reads and features.

Efficiency was tested with large BAM files. As MarkDuplicates is very slow, it was downsamples to 10 million reads, but samtools and bedtools were run with all reads.

- 400GB whole genome BAM: 3.5 hours
- 219GB exome BAM (262529 features): 5.2 hours

In both cases, bedtools was the limiting step. Memory usage is low for all tasks. 4GB is enough for very large BAM files. The workflow has no minimum read requirement. It will work with an empty BAM file.

Downstream users may want to normalize for any downsampling that was performed. It isn't possible to determine downsampling from the tool (samtools, picard, bedtools) output. The workflow generates a JSON file that records all downsampling that was set. If no downsampling was performed, the value will be `null`.

Samtools stats records and filters out non-primary and supplementary alignments by default. This ensures that the total read count matches the cluster count on the machine. The same read can be aligned multiple times. One alignment is the primary alignment and the rest are secondary alignments. Information is being multiplied because the aligner doesn't know which alignment is best. With supplementary alignments, a read is broken up across large distances (not introns). In this case information isn't being duplicated. Picard MarkDuplicates deals with primary and supplementary reads itself. For bedtools calculations, the non-primary alignments are excluded (as they falsely multiply coverage). Supplementary alignments are kept for bedtools.

The bash code is as simple as possible, with as few options used as possible. One complexity repeatedly seen comes in the form of `(samtools view -uF 256 ~{bam} || if [[ $? -eq 141 ]]; then true; else exit $?; fi) |`. A samtools command followed by blah, which is then piped onward. The blah part states to ignore exit code 141 (exit with 0 instead), otherwise exit with the actual return code. This is needed when samtools pipes more data to bedtools than bedtools needs. Bedtools shuts down as soon as it is done, leaving samtools with nowhere to stream the rest of the data to, leading it to exit with code 141. There isn't a way to tell bedtools to hang around until all the data is streamed (which is for the best, as that's wasted time). Telling samtools only to stream data that bedtools needs would mean samtools and bedtools do the same work twice (and I'm not sure the duplicated work would yield the same result). So the solution is to ignore that specific error code.

More complexity is seen in bedtools with `chrom.size` file creation. `bedtools coverage` needs a two column file with the chromosomes and their sizes. This information is in the BAM file, but bedtools doesn't use it. The WDL does that with a some awk.