The reasoning for creating this workflow is found in the [project charter](https://docs.google.com/document/d/1wNfZL1yIn2HO5O6AVxXCGK-won5Nx_e5V98KUI4dUNk/edit#heading=h.cyxk68tr97gk): "To remove the bamqc workflow from emSeqQc and replace it with something simpler and faster."

To get simplicity and efficiency, only the work necessary to generate QC Gate metrics is done in parallel:

- samtools stats: mean insert size
- picard MarkDuplicates: duplication percentage
- bedtools: coverage histogram

The workflow supports features (probes) for coverage calculations. If supplied, only those regions will be used to calculate coverage. If not, coverage will be calculated for all sites in the genome.

samtools and picard output is not changed. For bedtools output, only the global coverage histogram is kept. The per-chromosome or per-feature histograms are discarded. That level of detail is not needed for QC Gate coverage metric and would result in large files (100MB - 1GB).

Downsampling of input data is the way to increase efficiency. Bamqc uses random downsampling to an exact count. As the whole BAM file has to be read, this method of downsampling is slow. To increase downsampling efficiency, only the first N reads are used during downsampling. Each task (samtools, picard, bedtools) can independantly set how many reads to use. Downsampling is optional and won't be used if the downsampling parameter is not supplied. 

For samtools and bedtools, the downsampled BAM file is streamed. Picard MarkDuplicates requiers a file on disk, as it is a dual pass algorithm. If downsampling is done for MarkDuplicates, be aware that selecting a large number of reads to downsample to will result in a new large BAM file on disk.

Read downsampling may not work with bedtools coverage calculations if features (probes) are supplied. For example, if the first probe is on chr13, there will be a variable number of off target reads on chr1 through chr12. Selecting the first N reads to downsample will not work. Rather than downsampling BAM input reads, it is possible to downsample features, but selecting only the first N features. It is possible to downsample for both reads and features.

Efficiency was tested with large BAM files. As MarkDuplicates is very slow, it was downsamples to 10 million reads, but samtools and bedtools were run with all reads.

- 400GB WG BAM: 3.5 hours
- 219GB EX BAM (262529 features): 5.2 hours

In both cases, bedtools was the limiting step. Memory usage is low for all tasks. 4GB is enough for very large BAM files. The workflow has no minimum read requirement. It will work with an empty BAM file.

Downstream users may want to normalize for any downsampling that was performed. It isn't possible to determine downsampling from the tool (samtools, picard, bedtools) output. The workflow generates a JSON file that records all downsampling that was set. If no downsampling was performed, the value will be `null`.
