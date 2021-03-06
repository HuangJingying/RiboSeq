#!/bin/sh
#!/bin/bash

# bash 190215new_RNAseq.data1.cre.bash mRe0-1_1 > /home/data1/huangjingying/cc125/newRNAseq/cc125data/mRe0-1_1.log 2>&1 &
## 建立文件夹、转换目录
path="/home/data1/huangjingying/cc125/newRNAseq/cc125data"
echo $path
echo $1
mkdir $path/$1
cd  $path/$1
mkdir fastqc

zcat  $path/raw/$1.fq.gz | fastq_illumina_filter --keep N -v | fastx_clipper -a CTGTAGGCACCATCAAT -l 25 -c -n -v | fastx_trimmer -f 2 > $path/$1/$1_trimmed0.fq

cutadapt -M 65 -o $1_trimmed.fq $path/$1/$1_trimmed0.fq

fastqc -o  $path/$1/fastqc/ $1_trimmed.fq
rrna_index="/home/data1/WD_data1/Chlamydomonas_reinhardtii/rrna_index/rrna"
bowtie2 --quiet -p 20 -L 23 -x $rrna_index -q $1_trimmed.fq --un $path/$1/$1_norrna.fq
#echo "finish bowtie2 --quiet"
fastqc -o  $path/$1/fastqc/ $1_norrna.fq
echo "finish fastqc"

#---比对
genome_path="/home/data1/huangjingying/cc125/annotation"
gtf_file="Creinhardtii_281_v5.5.gene_exons.gff3"  #!!!!!!!!!!!!!!!!!!!!!!!!!!gff3 can not be used in htseq
genome_index=$genome_path/genome
tophat --no-novel-juncs --GTF $genome_path/$gtf_file $genome_index $path/$1/$1_norrna.fq
echo "finish tophat"
## 输出tophat结果
cat  ./tophat_out/align_summary.txt

samtools view -h  ./tophat_out/accepted_hits.bam | grep -E '(NM:i:0)|(^@)' | samtools view -Sb  - > $1.bam

samtools sort $1.bam -o $1_sorted.bam

samtools index  $1_sorted.bam

# echo "start count"
count_path="/home/data1/huangjingying/cc125/newRNAseq/cc125data/result/htseqcount"

##all_count
htseq-count  -f bam $1_sorted.bam $genome_path/$gtf_file > $1.all.txt
cat $1.all.txt | grep -v "^__"  >  $path/result/htseqcount/$1_all.txt
sed -i '1i\ID\tName\tcounts'  $path/result/htseqcount/$1_all.txt

for i in five_prime_UTR three_prime_UTR;
do echo $i;
htseq-count --additional-attr=gene_name -f bam -t $i $1_sorted.bam $genome_path/$gtf_file > $1.$i.txt
cat $1.$i.txt | grep -v "^__" >  $1_$i.txt 
# sed -i '1i\ID\tName\tcounts'  $path/result/htseqcount/$1_$i.txt
#补充
awk 'BEGIN {FS="\t";OFS="\t"} {print $1,$3}' $path/result/htseqcount/$1_$i.txt> $path/result/htseqcount/$1_$i.forR.txt
done;
cat $1_exon.txt | awk '{sum+=$3} END {print "exon Sum = ", sum}' > exonfeaturecount.txt
cat $1_CDS.txt | awk '{sum+=$3} END {print "CDS Sum = ", sum}' > CDSfeaturecount.txt
cat $1_five_prime_UTR.txt | awk '{sum+=$3} END {print "five_prime_utr Sum = ", sum}' > five_prime_UTRfeaturecount.txt
cat $1_three_prime_UTR.txt | awk '{sum+=$3} END {print "three_prime_utr Sum = ", sum}' > three_prime_UTRfeaturecount.txt

## 输出长度分布、utr比例、CDS counts
samtools view $1.bam | awk 'BEGIN{FS=OFS="\t"}{print length($10)}' | sort -n | uniq -c | awk 'BEGIN{FS=" "; OFS="\t"}{print}' | sort -nk1,1 >  $count_path/length/$1_length.txt
cat *featurecount.txt >  $count_path/CDS_utr_ratio/$1countsummary.txt
cp $1_exon.txt  $count_path/exon_count/
cp $1_CDS.txt  $count_path/CDS_count/
cp $1_five_prime_utr.txt  $count_path/5utr/
cp $1_three_prime_utr.txt  $count_path/3utr/

'''no need for mRNA data !!!!!!!!!!!!!!!!!!!!!!!!!!'
STAR --outFilterType BySJout --runThreadN 16 --outFilterMismatchNmax 0 --genomeDir $genome_path \
--readFilesIn $1_norrna.fq --outFileNamePrefix $1 \
--outSAMtype BAM SortedByCoordinate --quantMode TranscriptomeSAM GeneCounts --outFilterMultimapNmax 1 --outFilterMatchNmin 16 --alignEndsType EndToEnd

cat $1ReadsPerGene.out.tab | grep -v "N_" | cut -f 1,2 >  $path/result/star_count/$1_star_final.txt
mv $1Aligned.toTranscriptome.out.bam $path/result/starbam

#bam to bw
bw_path=$path/result/bw
bamCoverage -p 1 --bam $1_sorted.bam -o $bw_path --binSize 5 --normalizeUsing CPM
echo "$1 linux analysis finished!!!!"


mkdir /home/data1/WD_data1/Chlamydomonas_reinhardtii/credata/result/
mkdir /home/data1/WD_data1/Chlamydomonas_reinhardtii/credata/result/htseqcount/
mkdir /home/data1/WD_data1/Chlamydomonas_reinhardtii/credata/result/htseqcount/exon_count
mkdir /home/data1/WD_data1/Chlamydomonas_reinhardtii/credata/result/htseqcount/CDS_count
mkdir /home/data1/WD_data1/Chlamydomonas_reinhardtii/credata/result/htseqcount/5utr
mkdir /home/data1/WD_data1/Chlamydomonas_reinhardtii/credata/result/htseqcount/3utr
mkdir /home/data1/WD_data1/Chlamydomonas_reinhardtii/credata/result/htseqcount/length
mkdir /home/data1/WD_data1/Chlamydomonas_reinhardtii/credata/result/htseqcount/CDS_utr_ratio
mkdir /home/data1/WD_data1/Chlamydomonas_reinhardtii/credata/result/star_count/
mkdir /home/data1/WD_data1/Chlamydomonas_reinhardtii/credata/result/bw

#run first to produce genomeParameters.txt and others
STAR   --runMode genomeGenerate   --runThreadN 8   --genomeDir /home/data1/huangjingying/cc125/annotation   --genomeFastaFiles Creinhardtii_281_v5.0.fa \
 --sjdbGTFfile Creinhardtii_281_v5.5.gene_exons.updata.gtf

#190215new_RNAseq.data1.cre.star.bash

bash 190215new_RNAseq.data1.cre.star.bash mRe0-1_1 > /home/data1/huangjingying/cc125/newRNAseq/cc125data/mRe0-1_1.log 2>&1 &

